#pragma once
#include <cstdint>
#include "IDCConsoleLayout.h"

namespace IsaacConsole {
struct PauseLease {
    uintptr_t game=0;
    uint32_t seed=0;
    void Take(uintptr_t address,uint32_t runSeed) { game=address; seed=runSeed; }
    bool CanResume(uintptr_t address,uint32_t runSeed,bool stable,bool paused) const {
        return game && seed && game==address && seed==runSeed && stable && paused;
    }
    void Clear() { game=0; seed=0; }
};
}
