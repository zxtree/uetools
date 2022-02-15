#!/usr/bin/env ruby
# @author zxtree
# dir struct:
# root/
#   - UE_x.x/ 
#   - UE_y.y/
#   - ...
#   - projects/
#       - {PROJECT} ..

require 'inifile'

PLATFORM = "Win64"
UE_ROOT = "D:\\Epic Games"

UE_DIR = "#{UE_ROOT}\\UE_5.0EA2"
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

    def startGame
        modes = {
            "listen" => "\"#{UE_EXE}\" \"#{uproject}\" #{defaultMap}?Listen -game -windowed -log -resx=#{screenSize["X"]} -resy=#{screenSize["Y"]}",
            "client" => "\"#{UE_EXE}\" \"#{uproject}\" 127.0.0.1 -game -windowed -log -resx=#{screenSize["X"]} -resy=#{screenSize["Y"]}",
            "server" => "\"#{UE_EXE}\" \"#{uproject}\" #{defaultMap} -server -game -log"
        }
        
        cmd = modes[ARGV[1]] ? modes[ARGV[1]] : modes["listen"]
        spawn(cmd)
        #spawn()
    end

    def startEditor
        spawn("\"#{UE_EXE}\" \"#{uproject}\"")
    end

    def build
        target = @projectName
        if(ARGV[1] == "Editor")
            target = "#{@projectName}Editor"
        end
        
        cmd = "\"#{BUILD_BAT}\" #{target} #{PLATFORM} Development \"#{uproject}\" -waitmutex -NoHotReload"
        puts cmd
        `#{cmd}`
    end

    def generateProjectFile
        cmd = "\"#{UBT_EXE}\" -projectfiles -project=\"#{uproject}\" -game -rocket -progress -engine -VSCode"
        puts cmd
        `#{cmd}`
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
    puts "action: #{action}"
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