#pragma once

#include <pasty/runtime/runtime_config.h>

namespace pasty {

class CoreRuntimeHandle {
public:
    virtual ~CoreRuntimeHandle() = default;

    virtual bool start() = 0;
    virtual void stop() = 0;
    virtual bool isStarted() const = 0;
};

} // namespace pasty
