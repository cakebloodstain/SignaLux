#include <signalux/signalux.h>
#include <fmt/core.h>

namespace signalux
{

    std::string get_greeting(const std::string &name)
    {
        return fmt::format("Hello, {}!", name);
    }

} // namespace signalux
