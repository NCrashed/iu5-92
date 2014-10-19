module sim;

import std.algorithm;
import std.datetime;
import std.concurrency;
import std.container.dlist;
import std.typecons;
import std.random;
import core.thread;

import data;
import util;

struct Query
{
    size_t workstation;
    size_t server;
    
    TickDuration startStamp;
}

struct Response
{
    size_t workstation;
    
    TickDuration startStamp;
}

void workstationProcess(Duration To, Duration Tp, size_t workstationId, size_t serversCount)
{
    Thread.getThis.isDaemon = true;
    Tid cableProcessTid = receiveOnly!Tid;
    
    Duration totalLifetime = 0.dur!"msecs";
    size_t totalResponses = 0;
    auto startStamp = Clock.currAppTick;
    Duration loadTime = 0.dur!"msecs";
    Duration userLoadTime = 0.dur!"msecs";
    
    void postResponse(Response r)
    {
        loadTime += waitExp(To);
        totalLifetime += Clock.currAppTick - r.startStamp;
        totalResponses += 1; 
    }
    
    void genQuery()
    {
       auto query = Query(workstationId, uniform(0, serversCount), Clock.currAppTick);
       auto t = waitExp(Tp.exp);
       loadTime += t;
       userLoadTime += t;
       cableProcessTid.send(query);
    }
    
    genQuery();
    
    
    while(true) {
        receive(
            (Response r) {
                postResponse(r);
                genQuery();
            },
            (Tid asker) {
                double reactionTime = totalLifetime.total!"msecs" / cast(double)totalResponses;
                auto totalTime = cast(double)(cast(Duration)(Clock.currAppTick - startStamp)).total!"msecs";
                double loadFactor = loadTime.total!"msecs" / totalTime;
                double userLoadFactor = userLoadTime.total!"msecs" / totalTime;
                asker.send(reactionTime, loadFactor, userLoadFactor);
            }
        );
    }
}

void cableProcess(Duration tk, const Tid[] workstations, const Tid[] servers)
{
    Thread.getThis.isDaemon = true;
    auto startStamp = Clock.currAppTick;
    Duration loadTime = 0.dur!"msecs";
    
    while(true) {
        receive(
            (Response r) {
                loadTime += waitExp(tk);
                (cast()workstations[r.workstation]).send(r);
            },
            (Query q) {
                loadTime += waitExp(tk);
                (cast()servers[q.server]).send(q);
            },
            (Tid asker) {
                auto totalTime = cast(double)(cast(Duration)(Clock.currAppTick - startStamp)).total!"msecs";
                asker.send(loadTime.total!"msecs" / totalTime);
            }
        );
    }
}

void serverProcess(Duration ts)
{
    Thread.getThis.isDaemon = true;
    Tid cableProcessId = receiveOnly!Tid;
    TickDuration startStamp = Clock.currAppTick;
    Duration loadTime = 0.dur!"msecs";
    
    while(true) {
        receive(
            (Query q) {
                loadTime += waitExp(ts);
                cableProcessId.send(Response(q.workstation, q.startStamp));
            },
            (Tid asker) {
                auto totalTime = cast(double)(cast(Duration)(Clock.currAppTick - startStamp)).total!"msecs";
                asker.send(loadTime.total!"msecs" / totalTime);
            }
        );
    }
}
    
Duration mapTime(double v)
{
    return dur!"msecs"(cast(long)v);
}

Output startSimulation(Input input, Duration maxSimTime)
{
    Tid[] workstations;
    foreach(i; 0..input.wokrstationsCount)
    {
        workstations ~= spawn(&workstationProcess, input.afterProcessTime.mapTime, input.queringProcessTime.mapTime, i, input.serversCount);
    }
    
    Tid[] servers;
    foreach(i; 0..input.serversCount)
    {
        servers ~= spawn(&serverProcess, input.responseProcessTime.mapTime);
    }
    
    Tid cableProcessId = spawn(&cableProcess, input.sendingProcessTime.mapTime, cast(immutable)workstations, cast(immutable)servers);
    
    foreach(w; workstations) w.send(cableProcessId);
    foreach(s; servers) s.send(cableProcessId);
    
    Thread.sleep(maxSimTime);
    std.stdio.writeln("Simulation ended!");
    
    Tuple!(double, double, double)[] times;
    foreach(w; workstations)
    {
        w.send(thisTid);
        times ~= receiveOnly!(double, double, double);
    }
    auto wStat = times.mean;
    
    cableProcessId.send(thisTid);
    auto cableLoadFactor = receiveOnly!double();
    
    double[] serverTimes;
    foreach(s; servers)
    {
        s.send(thisTid);
        serverTimes ~= receiveOnly!double;
    }
    auto serverLoadFactor = serverTimes.mean;
    
    Output output;
    output.systemResponseTime = wStat[0];
    output.workstationLoad = wStat[1];
    output.userLoad = wStat[2];
    output.cableLoad = cableLoadFactor;
    output.serverLoad = serverLoadFactor;
    
    return output;
}