import vibe.data.json;

import std.file;
import std.getopt;
import std.stdio;
import std.datetime;

import data;
import sim;

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
    
    auto output = startSimulation(input, dur!"seconds"(10));
    writeln("Output: ", output);
    output.save(outputFileName);
}

immutable helpMsg = 
`Tool for simulation modeling for coursework IU5-92 Gushcha Anton 2014.
   
Arguments:
    --example=name - generate example input file at name
    --input=name - load input data from name
    --output=name - save result to name, default is 'output.json'
    --help or -h - show this message
`;