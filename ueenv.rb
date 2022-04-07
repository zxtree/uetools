#!/usr/bin/env ruby
# @author zxtree
# dir struct:
# root/
#   - UE_x.x/ 
#   - UE_y.y/
#   - ...
#   - tools/
#       - ueenv.rb {this file}
#   - projects/
#       - {PROJECT} ..

require 'inifile'
require 'Open3'
require 'JSON'

PLATFORM = "Win64"
UE_ROOT = "D:\\Unreal"

UE_DIR = "#{UE_ROOT}\\UE-5.0"
UE_EXE = "#{UE_DIR}\\Engine\\Binaries\\#{PLATFORM}\\UnrealEditor.exe" #UE4Editor.exe for UE4
UBT_DIR = "#{UE_DIR}\\Engine\\Binaries\\DotNET\\UnrealBuildTool"
UBT_EXE = "#{UBT_DIR}\\UnrealBuildTool.exe"
BUILD_BAT = "#{UE_DIR}\\Engine\\Build\\BatchFiles\\Build.bat"

PROJECTS_ROOT = "#{UE_ROOT}\\projects"

class UEProject    
    def initialize(pname)
        @projectName = pname
        @defaultEngine = IniFile.load("#{root}\\Config\\DefaultEngine.ini")

        if !File.exists?(uproject)
            raise "Project dir invalid"
        end
    end

    def root
        "#{PROJECTS_ROOT}\\#{@projectName}"
    end

    def uproject
        "#{root}\\#{@projectName}.uproject"
    end

    def workspace
        "#{root}\\#{@projectName}.code-workspace"
    end

    def defaultMap
        @defaultEngine["/Script/EngineSettings.GameMapsSettings"]["GameDefaultMap"]
    end

    def screenSize
        size = @defaultEngine["/Script/Engine.UserInterfaceSettings"]["DesignScreenSize"]
        reso = {}
        size.delete("(").delete(")").split(",").map{|line| 
            cons = line.split("=")
            reso[cons[0]] = cons[1]
        }
        return reso
    end

    def packageDir
        "#{root}\\Package\\Windows"
    end

    def packageExe
        "#{packageDir}\\#{@projectName}.exe"
    end

    def remoteAddr
        remoteAddr = "127.0.0.1"
    end

    def gameParam
        {
            "listen" => [
                uproject,
                "-game",
                "#{defaultMap}?Listen",
                "-windowed",
                "winx=200",
                "winy=200",
                "resx=#{screenSize["X"]}",
                "resy=#{screenSize["Y"]}",
                "-ExecCmds=\"stat fps\"",
            ],
            "client" => [
                uproject,
                "-game",
                remoteAddr,
                "-windowed",
                "winx=1000",
                "winy=200",
                "resx=#{screenSize["X"]}",
                "resy=#{screenSize["Y"]}",
                "-ExecCmds=\"stat fps\"",
            ]
        }
    end

    def toParamStr(arr)
        arr[0] = "\"#{arr[0]}\""
        arr.join(" ")
    end

    def startGame
        mode = ARGV[1] ? ARGV[1] : "listen"
        
        params = ARGV.slice(2, ARGV.size - 1)
        params = params && params.size > 0 ? params.join(" ") : nil
        cmd = params ? "\"#{UE_EXE}\" \"#{params}\"" : "\"#{UE_EXE}\" #{toParamStr(gameParam[mode].push("-log"))}"
        #pus cmd
        printCmd(cmd)
        spawn(cmd)
        #Open3.pipeline(cmd)
    end

    def startEditor
        params = ARGV.slice(1, ARGV.size - 1)
        params = params ? params.join(" ") : ""
        cmd = "\"#{UE_EXE}\" \"#{uproject}\" #{params}"
        #puts cmd
        printCmd(cmd)
        spawn(cmd)
    end

    def packed
        cmd = nil
        case ARGV[1]
        when "listen"
            cmd = "\"#{packageExe}\" #{defaultMap}?Listen"
        when "client"
            remoteAddr = ARGV[2] ? ARGV[2] : "127.0.0.1"
            cmd = "\"#{packageExe}\" #{remoteAddr}"            
        else
            params = ARGV.slice(1,ARGV.size - 1)
            cmd = "\"#{packageExe}\" #{params}"
        end
        printCmd(cmd)
        spawn(cmd)
    end

    def build
        target = "#{@projectName}Editor"
        
        if ARGV[1]
            target = ARGV[1]
        end
        
        cmd = "\"#{BUILD_BAT}\" #{target} #{PLATFORM} Development \"#{uproject}\" -waitmutex -NoHotReload"
        printCmd(cmd)
        Open3.pipeline(cmd)
    end

    def generateProjectFile
        cmd = "rm -r \"#{root}\\.vscode\\compileCommands_#{@projectName}\"| \"#{UBT_EXE}\" -projectfiles -project=\"#{uproject}\" -game -rocket -progress -engine -VSCode"
        #cmd = "rm -r \"#{root}\\.vscode\\compileCommands_#{@projectName}\""
        printCmd(cmd)
        Open3.pipeline(cmd)
        alterLaunch
        alterTask
    end

    def vscodeRoot
        "#{root}\\.vscode"
    end

    def taskFile
        "#{vscodeRoot}\\tasks.json"
    end

    def launchFile
        "#{vscodeRoot}\\launch.json"
    end

    def alterLaunch
        launch = JSON.parse(File.read(launchFile))
        conf = launch["configurations"]
        conf = conf.delete_if {|element| element["name"] == "Debug Client" || element["name"] == "Debug Listen"}

        debug = {
            "name" => "Debug Listen",
            "args" => gameParam["listen"],
            "request" => "launch",
            "preLaunchTask" => "TPPEditor Win64 Development Build",
            "program" => "#{UE_EXE}",
            "cwd" => "#{UE_DIR}",
            "stopAtEntry" => false,
            "externalConsole" => false,
            "type" => "cppvsdbg",
            "visualizerFile" => "#{UE_DIR}\\Engine\\Extra\\VisualStudioDebugging\\Unreal.natvis"
        }

        conf.push(debug)

        client = debug.clone
        client["name"] = "Debug Client"
        client["args"] = gameParam["client"]
        conf.push(client)

        launch["configurations"] = conf
        launchStr = JSON.pretty_generate(launch)
        #puts launchStr
        wFile = File.open(launchFile, "w")
        wFile.write(launchStr)
        wFile.close
    end
    
    def alterTask
        task = JSON.parse(File.read(taskFile))

        task["tasks"].delete_if {|t| t["label"].index("HoloLens")}

        wFile = File.open(taskFile, "w")
        wFile.write(JSON.pretty_generate(task))
        wFile.close
        #puts JSON.pretty_generate(task)
    end

    def code
        cmd = "code \"#{workspace}\""
        printCmd(cmd)
        spawn(cmd)
    end

    def ueenv
        cmd = "code \"#{UE_ROOT}\\tools\\ueenv.rb\""
        printCmd(cmd)
        spawn(cmd)
    end
end

def cwd
    pwd = Dir.pwd.split("/")
    pwd[pwd.size - 1]
end

def printHelpMsg
    puts "run in project folder"
    puts "Usage: ruby [this script] [actions: game | editor | build...] [arguments]"
end

def printCmd(cmd)
    puts "-- command: #{cmd}"
    puts "***********"
end

#entry
def main
    if ARGV.size == 0
        printHelpMsg
        return
    end

    begin
        project = UEProject.new(cwd)
    rescue Exception => e
        puts e.message
        puts "project name: #{cwd}"        
        puts e.backtrace.inspect
        return
    end

    action = ARGV[0]
    puts "-- action: #{action}"
    case action
        when "game"
            project.startGame
        when "editor"
            project.startEditor
        when "build"
            project.build
        else
            begin
                project.send(action)
            rescue Exception => e
                puts e.message
                puts "invalid action: #{action}"
            end
    end
end
main