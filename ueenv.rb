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
        spawn("\"#{UE_EXE}\" \"#{uproject}\" #{defaultMap}?Listen -game -windowed -log -resx #{screenSize["X"]} -resy = #{screenSize["Y"]}")
    end

    def startEditor
        spawn("\"#{UE_EXE}\" \"#{uproject}\"")
    end

    def build
        spawn("\"#{BUILD_BAT}\" #{projectName}Editor #{PLATFORM} Development #{uproject} -waitmutex -NoHotReload")
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
            puts "invalid action: #{action}"
    end
end
main