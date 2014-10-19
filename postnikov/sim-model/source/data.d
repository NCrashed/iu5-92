module data;

import vibe.data.json;
import std.stdio;
import std.file;

struct Input
{
    size_t wokrstationsCount;
    size_t serversCount;
    double afterProcessTime;
    double queringProcessTime;
    double responseProcessTime;
    double sendingProcessTime;
    
    static void genExample(string filename)
    {
        auto example = Input(8, 2, 80, 80, 10, 10).serializeToJson;
        auto builder = appender!string;
        
        writePrettyJsonString(builder, example);
        
        auto file = File(filename, "w");
        scope(exit) file.close();
        file.write(builder.data);
    }
}

struct Output
{
    double systemResponseTime;
    double workstationLoad;
    double cableLoad;
    double serverLoad;
    double userLoad;
    
    void save(string filename)
    {
        auto builder = appender!string;
        writePrettyJsonString(builder, this.serializeToJson);
        
        auto file = File(filename, "w");
        scope(exit) file.close();
        file.write(builder.data);
    }
    
    void toString(scope void delegate(const(char)[]) sink) const
    {
        writePrettyJsonString(sink, this.serializeToJson);
    }
}