#pragma once

#include "llvm/ADT/DenseMap.h"

namespace llvm {

class ScheduleDAGInstrs;

namespace AMDGPU {

class ResourceDistanceMaps {
public:
  struct SUDistRank {
    int ToRoot;
    int Dist;
    SUDistRank(int ToRoot, int Dist = -1): ToRoot(ToRoot), Dist(Dist) {}
    bool operator<(const SUDistRank& other) const {
      if (ToRoot != other.ToRoot) {
        return ToRoot < other.ToRoot;
      }
      return Dist > other.Dist;
    }
    bool operator>(const SUDistRank& other) const {
      return other < *this;
    }
  };
private:
  using DistMapTy = DenseMap<SUnit *, DenseMap<SUnit *, unsigned>>;
  struct ResourceRootInfo {
    /// Number of root SU that is predecessor of this root.
    unsigned PredRootsLeft = 0;
    /// At which cycle this node may be scheduled, only meaning full when
    /// PredRootsLeft is zero.
    unsigned TopReadyCycle = 0;
    /// Order between roots, lower is preferred for scheduling, uint-max means
    /// has other root predecessor to be scheduled.
    unsigned Order;
  };
  using RootInfosTy = DenseMap<SUnit *, ResourceRootInfo>;

  struct ResourceInfo {
    DistMapTy DistMap;
    RootInfosTy RootInfos;
    DenseMap<SUnit *, SUDistRank> SURankCache;

    unsigned getOrderForRoot(SUnit *Root) const;
    void sortRoots(ScheduleDAGInstrs *DAG);
    void schedNode(SUnit *SU, unsigned CurrCycle, ScheduleDAGInstrs*DAG);
    SUDistRank getSURank(SUnit *SU);
    SUDistRank getSURankImpl(SUnit *SU);
    bool isRoot(SUnit *SU) const {
      return RootInfos.find(SU) != RootInfos.end();
    }

    ResourceInfo(DistMapTy &&DistMap, RootInfosTy &&RootInfos)
        : DistMap(std::move(DistMap)), RootInfos(std::move(RootInfos)) {}
  };

  DenseMap<unsigned, ResourceInfo> Maps;
  friend class ResourceDistanceMapBuilder;
  static ResourceInfo build(ScheduleDAGInstrs *DAG, unsigned ResourceID);

  ResourceInfo &ensureResDistMap(unsigned ResourceID);

  ScheduleDAGInstrs *DAG = nullptr;

public:
  ResourceDistanceMaps() {}
  void initialize(ScheduleDAGInstrs *DAG) {
    this->DAG = DAG;
    Maps.clear();
  }
  SUDistRank getSUnitRankForRes(SUnit *SU, unsigned ResourceID) const;
  void schedNode(SUnit *SU, unsigned CurrCycle);
};

} // namespace AMDGPU
} // namespace llvm
