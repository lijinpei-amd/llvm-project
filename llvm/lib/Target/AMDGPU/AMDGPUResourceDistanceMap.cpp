#include "AMDGPUResourceDistanceMap.h"

#include "llvm/ADT/GraphTraits.h"
#include "llvm/ADT/STLExtras.h"
#include "llvm/CodeGen/ScheduleDAGInstrs.h"

#include <deque>
#include <limits>

namespace llvm {
namespace AMDGPU {
// TOOD: Support BottomUp
class ResourceDistanceMapBuilder {
  DenseMap<SUnit *, unsigned> SuccsLeft;
  ResourceDistanceMaps::DistMapTy DistMap;
  ResourceDistanceMaps::RootInfosTy RootInfos;

  ScheduleDAGInstrs *DAG;
  unsigned ResourceID;

  bool isRoot(const SUnit *SU) const {
    return RootInfos.find(SU) != RootInfos.end();
  }

  void getReachableNodes() {
    auto *SchedModel = DAG->getSchedModel();
    SmallVector<SUnit *> WorkList;
    for (auto *SU : nodes(static_cast<ScheduleDAG *>(DAG)))
      if (auto *SC = DAG->getSchedClass(SU))
        for (auto &ProcRes : make_range(SchedModel->getWriteProcResBegin(SC),
                                        SchedModel->getWriteProcResEnd(SC)))
          if (ProcRes.ProcResourceIdx == ResourceID) {
            RootInfos.try_emplace(SU, ResourceDistanceMaps::ResourceRootInfo{});
            WorkList.push_back(SU);
            break;
          }
    while (!WorkList.empty()) {
      auto *SU = WorkList.pop_back_val();
      for (auto &Pred : SU->Preds) {
        auto *PredSU = Pred.getSUnit();
        auto [Iter, Inserted] = SuccsLeft.try_emplace(PredSU, 0);
        if (Inserted && !isRoot(PredSU))
          WorkList.push_back(PredSU);
        Iter->second += 1;
      }
    }
  }
  void buildDistanceMap() {
    std::deque<SUnit *> WorkList;
    for (auto &[Root, _] : RootInfos) {
      WorkList.push_back(Root);
    }
    while (!WorkList.empty()) {
      auto *SU = WorkList.front();
      WorkList.pop_front();
      for (auto &Pred : SU->Preds) {
        auto *PredSU = Pred.getSUnit();
        if (--SuccsLeft[PredSU] == 0) {
          buildDistanceMapForNode(PredSU);
          WorkList.push_back(PredSU);
        }
      }
    }
  }

  void buildDistanceMapForNode(SUnit *SU) {
    auto &Succs = DistMap[SU];
    for (auto &Succ : SU->Succs) {
      auto *SuccSU = Succ.getSUnit();
      if (isRoot(SuccSU)) {
        // Don't populate second-order roots.
        auto &CurrDist = Succs[SuccSU];
        CurrDist = std::max(SU->Latency + Succ.getLatency(), CurrDist);
      } else {
        auto *SuccSU = Succ.getSUnit();
        // Don't trigger a re-hash.
        if (auto SuccDists = DistMap.find(SuccSU); SuccDists != DistMap.end())
          for (auto [SuccRoot, RootDist] : SuccDists->second) {
            auto &CurrDist = Succs[SuccRoot];
            CurrDist =
                std::max(SU->Latency + Succ.getLatency() + RootDist, CurrDist);
          }
      }
    }
  }

  void initializeRoots() {
    for (auto *SU : nodes(static_cast<ScheduleDAG *>(DAG)))
      if (SU->isTopReady()) {
        auto Iter = DistMap.find(SU);
        if (Iter == DistMap.end())
          continue;
        for (auto [RootSU, Dist] : Iter->second) {
          auto &RootInfo = RootInfos[RootSU];
          RootInfo.TopReadyCycle = std::max(RootInfo.TopReadyCycle, Dist);
        }
      }
    for (auto [RootSU, _] : RootInfos) {
      auto Iter = DistMap.find(RootSU);
      if (Iter == DistMap.end())
        continue;
      for (auto [SuccRoot, _] : Iter->second)
        // Won't trigger a re-hash
        ++RootInfos[SuccRoot].PredRootsLeft;
    }
  }

public:
  ResourceDistanceMapBuilder(ScheduleDAGInstrs *DAG, unsigned ResourceID)
      : DAG(DAG), ResourceID(ResourceID) {}

  ResourceDistanceMaps::ResourceInfo build() {
    getReachableNodes();
    buildDistanceMap();
    initializeRoots();
    ResourceDistanceMaps::ResourceInfo Res(std::move(DistMap),
                                           std::move(RootInfos));
    Res.sortRoots();
    return Res;
  }
};
ResourceDistanceMaps::ResourceInfo
ResourceDistanceMaps::build(ScheduleDAGInstrs *DAG, unsigned ResourceID) {
  return ResourceDistanceMapBuilder(DAG, ResourceID).build();
}

unsigned
ResourceDistanceMaps::ResourceInfo::getOrderForRoot(SUnit *Root) const {
  auto Iter = RootInfos.find(Root);
  assert(Iter != RootInfos.end());
  return Iter->second.Order;
}

void ResourceDistanceMaps::ResourceInfo::sortRoots() {
  SmallVector<SUnit *> AvailableRoots;
  for (auto &RootInfo : RootInfos)
    if (RootInfo.second.PredRootsLeft == 0) {
      AvailableRoots.push_back(RootInfo.first);
    } else {
      RootInfo.second.Order = std::numeric_limits<unsigned>::max();
    }
  auto Comp = [&](SUnit *LHS, SUnit *RHS) {
    if (LHS->TopReadyCycle != RHS->TopReadyCycle)
      return LHS->TopReadyCycle < RHS->TopReadyCycle;
    return LHS->NodeNum < RHS->NodeNum;
  };
  sort(AvailableRoots, Comp);
  for (auto [Idx, SU] : enumerate(AvailableRoots)) {
    RootInfos[SU].Order = Idx;
  }
  SURankCache.clear();
}

void ResourceDistanceMaps::ResourceInfo::schedNode(SUnit *SU) {
  auto Iter = DistMap.find(SU);
  if (Iter == DistMap.end()) {
    return;
  }
  bool IsRoot = isRoot(SU);
  bool Changed = false;
  for (auto [RootSU, Dist] : Iter->second) {
    auto &RootInfo = RootInfos[RootSU];
    if (IsRoot) {
      --RootInfo.PredRootsLeft;
      Changed = true;
    }
    unsigned NewCycle = SU->TopReadyCycle + Dist;
    if (NewCycle > RootInfo.TopReadyCycle) {
      RootInfo.TopReadyCycle = NewCycle;
      Changed = true;
    }
  }
  if (Changed) {
    sortRoots();
  }
}

int ResourceDistanceMaps::ResourceInfo::getSURank(SUnit *SU) {
  auto Iter = SURankCache.find(SU);
  if (Iter != SURankCache.end()) {
    return Iter->second;
  }
  auto Res = getSURankImpl(SU);
  SURankCache[SU] = Res;
  return Res;
}

int ResourceDistanceMaps::ResourceInfo::getSURankImpl(SUnit *SU) {
  // Prefer roots.
  if (isRoot(SU)) {
    return -1;
  }

  // Prefer nodes leading to roots.
  int Res = std::numeric_limits<int>::max();
  auto Iter = DistMap.find(SU);
  if (Iter == DistMap.end()) {
    return Res;
  }

  // Prefer nodes leading to closer roots.
  for (auto [Root, _] : Iter->second) {
    auto &RootInfo = RootInfos[Root];
    if (RootInfo.PredRootsLeft == 0) {
      Res = std::min(Res, int(RootInfo.Order));
    }
  }
  return Res;
}

ResourceDistanceMaps::ResourceInfo &
ResourceDistanceMaps::ensureResDistMap(unsigned ResourceID) {
  auto Iter = Maps.find(ResourceID);
  if (Iter != Maps.end())
    return Iter->second;
  return Maps.try_emplace(ResourceID, build(DAG, ResourceID)).first->second;
}

int ResourceDistanceMaps::getSUnitRankForRes(SUnit *SU,
                                             unsigned ResourceID) const {
  return const_cast<ResourceDistanceMaps *>(this)
      ->ensureResDistMap(ResourceID)
      .getSURank(SU);
}

void ResourceDistanceMaps::schedNode(SUnit *SU) {
  for (auto &[_, ResInfo] : Maps)
    ResInfo.schedNode(SU);
}

} // namespace AMDGPU
} // namespace llvm
