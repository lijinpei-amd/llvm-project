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
        if (Pred.isArtificial() || Pred.isWeak()) {
	  continue;
	}
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
        if (Pred.isArtificial() || Pred.isWeak()) {
	  continue;
	}
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
      if (Succ.isArtificial() || Succ.isWeak()) {
        continue;
      }
      auto *SuccSU = Succ.getSUnit();
      if (isRoot(SuccSU)) {
        // Don't populate second-order roots.
        auto &CurrDist = Succs[SuccSU];
        CurrDist = std::max(Succ.getLatency(), CurrDist);
      } else {
        auto *SuccSU = Succ.getSUnit();
        // Don't trigger a re-hash.
        if (auto SuccDists = DistMap.find(SuccSU); SuccDists != DistMap.end())
          for (auto [SuccRoot, RootDist] : SuccDists->second) {
            auto &CurrDist = Succs[SuccRoot];
            CurrDist =
                std::max(Succ.getLatency() + RootDist, CurrDist);
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

  void dumpDistMap(ScheduleDAGInstrs* DAG) {
    for (const auto& kv: DistMap) {
      llvm::errs() << "from node: ";
      DAG->dumpNode(*kv.first);
      for (const auto& kv1: kv.second) {
      llvm::errs() << "to node dis: " << kv1.second << "\n";
      DAG->dumpNode(*kv1.first);
      }
    }
  }
public:
  ResourceDistanceMapBuilder(ScheduleDAGInstrs *DAG, unsigned ResourceID)
      : DAG(DAG), ResourceID(ResourceID) {}

  ResourceDistanceMaps::ResourceInfo build() {
    getReachableNodes();
    buildDistanceMap();
    initializeRoots();
    dumpDistMap(DAG);
    ResourceDistanceMaps::ResourceInfo Res(std::move(DistMap),
                                           std::move(RootInfos));
    Res.sortRoots(DAG);
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

void ResourceDistanceMaps::ResourceInfo::sortRoots(ScheduleDAGInstrs *DAG) {
  llvm::errs() << "sortRoots\n";
  SmallVector<std::pair<SUnit*, ResourceRootInfo>*> AvailableRoots;
  for (auto &RootInfo : RootInfos) {
  DAG->dumpNode(*RootInfo.first);
  llvm::errs() << "PredRootsLeft: " << RootInfo.second.PredRootsLeft << "\n";
    if (RootInfo.second.PredRootsLeft == 0 && !RootInfo.first->isScheduled) {
      AvailableRoots.push_back(&RootInfo);
    } else {
      RootInfo.second.Order = std::numeric_limits<unsigned>::max();
    }
    }
  auto Comp = [&](const std::pair<SUnit*, ResourceRootInfo> *LHS, const std::pair<SUnit*, ResourceRootInfo>*RHS) {
    auto LHSCycle = LHS->second.TopReadyCycle;
    auto RHSCycle = RHS->second.TopReadyCycle;
    if (LHSCycle != RHSCycle) {
      return LHSCycle < RHSCycle;
    }
    return LHS->first->NodeNum < RHS->first->NodeNum;
  };
  sort(AvailableRoots, Comp);
  llvm::errs() << "roots:\n";
  for (auto [Idx, KV] : enumerate(AvailableRoots)) {
    KV->second.Order = Idx;
    llvm::errs() << "ready cycle: " << KV->second.TopReadyCycle << "\n";
    DAG->dumpNode(*KV->first);
  }
  SURankCache.clear();
}

bool ResourceDistanceMaps::ResourceInfo::schedNode(SUnit *SU0, unsigned CurrCycle, ScheduleDAGInstrs* DAG) {
  bool IsRoot = isRoot(SU0);
  llvm::errs() << "IsRoot: " << IsRoot << "\n";
  DAG->dumpNode(*SU0);
  llvm::errs() << "Roots: " << RootInfos.size() << "\n";
  for (const auto& KV: RootInfos) {
  DAG->dumpNode(*KV.first);
  }
  auto Iter = DistMap.find(SU0);
  if (Iter == DistMap.end()) {
    return IsRoot;
  }
  bool Changed = false;
    if (IsRoot) {
  for (auto [RootSU, Dist] : Iter->second) {
    auto &RootInfo = RootInfos[RootSU];
    llvm::errs() << "from root to root:\n";
    DAG->dumpNode(*SU0);
    DAG->dumpNode(*RootSU);
      --RootInfo.PredRootsLeft;
      Changed = true;
    }
    }
  for (const auto& [SU, ToRoots]: DistMap) {
    unsigned RefCycle = SU->isScheduled ? SU->TopReadyCycle : CurrCycle + 1;
    for (auto [RootSU, Dist] : ToRoots) {
    auto &RootInfo = RootInfos[RootSU];
    unsigned NewCycle = RefCycle+ Dist;
    if (NewCycle > RootInfo.TopReadyCycle) {
      RootInfo.TopReadyCycle = NewCycle;
      Changed = true;
    }
    }
  }
  if (Changed) {
    sortRoots(DAG);
  }
  return IsRoot;
}

ResourceDistanceMaps::SUDistRank ResourceDistanceMaps::ResourceInfo::getSURank(SUnit *SU) {
  auto Iter = SURankCache.find(SU);
  if (Iter != SURankCache.end()) {
    return Iter->second;
  }
  auto Res = getSURankImpl(SU);
  SURankCache.try_emplace(SU, Res);
  return Res;
}

ResourceDistanceMaps::SUDistRank ResourceDistanceMaps::ResourceInfo::getSURankImpl(SUnit *SU) {
  // Prefer roots.
  if (isRoot(SU)) {
    return {-1};
  }

  SUDistRank Res{std::numeric_limits<int>::max()};
  // Prefer nodes leading to roots.
  auto Iter = DistMap.find(SU);
  if (Iter == DistMap.end()) {
    return Res;
  }

  // Prefer nodes leading to closer roots.
  for (auto [Root, Dist] : Iter->second) {
    auto &RootInfo = RootInfos[Root];
    if (RootInfo.PredRootsLeft == 0) {
      SUDistRank NewRes{(int)RootInfo.Order, (int)Dist};
      if (NewRes < Res)
	Res = NewRes;
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

ResourceDistanceMaps::SUDistRank ResourceDistanceMaps::getSUnitRankForRes(SUnit *SU,
                                             unsigned ResourceID) const {
  return const_cast<ResourceDistanceMaps *>(this)
      ->ensureResDistMap(ResourceID)
      .getSURank(SU);
}

bool ResourceDistanceMaps::schedNode(SUnit *SU, unsigned CurrCycle) {
        bool anyRoot = false;
  for (auto &[_, ResInfo] : Maps)
    anyRoot |= ResInfo.schedNode(SU, CurrCycle, DAG);
   return anyRoot;
}

} // namespace AMDGPU
} // namespace llvm
