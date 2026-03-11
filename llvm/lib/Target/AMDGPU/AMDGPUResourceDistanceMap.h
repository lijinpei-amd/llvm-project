#pragma once

#include "llvm/ADT/DenseMap.h"

namespace llvm {

class ScheduleDAGInstrs;

namespace AMDGPU {

class ResourceDistanceMaps {
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
    DenseMap<SUnit *, int> SURankCache;

    unsigned getOrderForRoot(SUnit *Root) const;
    void sortRoots();
    void schedNode(SUnit *SU);
    int getSURank(SUnit *SU);
    int getSURankImpl(SUnit *SU);
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
  int getSUnitRankForRes(SUnit *SU, unsigned ResourceID) const;
  void schedNode(SUnit *SU);
};

} // namespace AMDGPU
} // namespace llvm
