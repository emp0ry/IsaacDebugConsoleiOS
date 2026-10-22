#include "IDCConsolePolicy.hpp"
#include <cassert>
#include <iostream>
int main() {
    IsaacConsole::PauseLease lease;
    assert(!lease.CanResume(10,20,true,true)); // Already paused before opening.
    lease.Take(10,20); assert(lease.CanResume(10,20,true,true));
    assert(!lease.CanResume(11,20,true,true)); // New game object.
    assert(!lease.CanResume(10,21,true,true)); // Restarted run.
    assert(!lease.CanResume(10,20,false,true)); // Transition / background.
    assert(!lease.CanResume(10,20,true,false)); // Already resumed elsewhere.
    lease.Clear(); assert(!lease.CanResume(10,20,true,true));
    for (double width:{320.,812.,1200.,1800.,2560.}) {
        auto r=IDCFullPanel(width,900,0);
        assert(r.x==0 && r.y==0 && r.width==width && r.height==900);
        r=IDCFullPanel(width,900,300); assert(r.height==600);
        r=IDCFullPanel(width,900,1000); assert(r.height==1);
        r=IDCFullPanel(width,900,-1); assert(r.height==900);
    }
    assert(IDCFullPanel(0,900,0).width==0);
    std::cout<<"Console policies passed: pause ownership, same-run resume, background safety, fullscreen/keyboard layout\n";
}
