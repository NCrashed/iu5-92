import vibe.data.json;

import std.array;
import std.getopt;
import std.file;
import std.stdio;
import std.math;

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

void main(string[] args)
{
    string exampleInputName = "";
    bool needHelp = false;
    string inputFileName = "";
    string outputFileName = "output.json";
    
    getopt(args,
        "example", &exampleInputName,
        "input", &inputFileName,
        "output", &outputFileName,
        "help|h", &needHelp
    );
    
    if(needHelp)
    {
        writeln(helpMsg);
        return;
    }
    
    if(exampleInputName != "")
    {
        Input.genExample(exampleInputName);
        return;
    }
    
    if(inputFileName == "")
    {
        writeln("Input file isn't specified!");
        writeln(helpMsg);
        return;
    }
    
    immutable input = deserializeJson!Input(readText(inputFileName));
    writeln("Readed input: ", input);
    input.solve.save(outputFileName);
}

T min(T)(T a, T b)
{
    return a <= b ? a : b;
}

Output solve(const Input input)
{
    
    enum K1 = 0.995;
    enum K2 = 100;
    enum delta = 0.0001;
    
    immutable Pi = 1 / cast(double)input.serversCount;
    double background = K1 * min( 1 / (2*input.sendingProcessTime), 1 / (Pi*input.responseProcessTime) ) * ((input.wokrstationsCount - 1)/cast(double)input.wokrstationsCount); 
    writeln("Initial background", background);
    
    Output finalCalc(double Tk, double Ts)
    {
        Output output;
        output.systemResponseTime = input.afterProcessTime + input.queringProcessTime + Tk + Ts;
        immutable lambda = input.wokrstationsCount / output.systemResponseTime;
        
        output.workstationLoad = (input.afterProcessTime + input.queringProcessTime) / output.systemResponseTime;
        output.userLoad = input.queringProcessTime / output.systemResponseTime;
        output.cableLoad = 2 * lambda * input.sendingProcessTime;
        output.serverLoad = lambda * Pi * input.responseProcessTime;
        
        writeln("Output calculated: ", output);
        return output;
    }
    
    enum maxIterations = 10000;
    size_t lastIteration = 0;
    double lastTk, lastTs, lastDiff;
    foreach(i; 0..maxIterations)
    {
        writeln("Iteration ", i);
        
        immutable Tk = (2*input.sendingProcessTime)/(1 - 2*background*input.responseProcessTime); lastTk = Tk;
        immutable Ts = input.responseProcessTime / (1 - Pi*background*input.responseProcessTime); lastTs = Ts;
        immutable backgroundTest = (input.wokrstationsCount - 1) / (input.afterProcessTime + input.queringProcessTime + Tk + Ts); 
        immutable diff = abs(background - backgroundTest) / background; lastDiff = diff;
        
        writeln("Tk = ", Tk);
        writeln("Ts = ", Ts);
        writeln("New background = ", backgroundTest);
        writeln("diff = ", diff);
        
        if(diff < delta)
        {
            writeln("Diff is sufficient");
            return finalCalc(Tk, Ts);
        }
        
        writeln("Diff isn't sufficient");
        background = background - (background - backgroundTest) / cast(double)K2;
        writeln("Setting background to ", background);
        lastIteration = i;
    }
    
    writeln("Stopping at iteration ", lastIteration, " with diff = ", lastDiff);
    return finalCalc(lastTk, lastTs);
}

immutable helpMsg = 
`Tool for analytic modeling for coursework IU5-92 Gushcha Anton 2014.
   
Arguments:
    --example=name - generate example input file at name
    --input=name - load input data from name
    --output=name - save result to name, default is 'output.json'
    --help or -h - show this message
`;