#!/usr/bin/python3

import os
import sys
import glob
import time
import math
import subprocess


def find_compiler():
    options = ("clang++", "g++")
    if sys.argv.count("--gcc") == 1:
        options = ("g++",)
    if sys.argv.count("--llvm") == 1:
        options = ("clang++",)

    for compiler in options:
        try:
            subprocess.check_output(("which", compiler))
            return compiler
        except subprocess.CalledProcessError:
            continue
    print("Unable to find a c++ compiler.\n")
    exit(1)


def pkg_config(args):
    return subprocess.check_output(args.split(' ')).decode().strip().split(' ')


def build_program():
    if os.path.split(os.getcwd())[-1] == "linux":
        os.chdir("..")
        
    compiler = [find_compiler()]
    compiler_args = ["-osdf_experiment", "-std=c++14", "-Idependencies/glad/include/"]
    linker_args = pkg_config("pkg-config --static --libs glfw3")
    linker_args += pkg_config("pkg-config --static --libs glm")
    defines = {}

    debug_build = bool(sys.argv.count("--debug") or sys.argv.count("-d"))
    renderdoc_build = bool(sys.argv.count("--renderdoc") or sys.argv.count("-r"))

    if debug_build or renderdoc_build:
        print("\x1b[3;30;47m{}\x1b[0m".format("Now with debugging!"))
        compiler_args += ['-O0', '-g']
        defines["DEBUG_BUILD"] = 1
    else:
        compiler_args += ['-O3']

    if renderdoc_build:
        defines["RENDERDOC_CAPTURE_AND_QUIT"] = 1
        print("    \x1b[3;30;47m{}\x1b[0m".format("...and RenderDoc!"))

    sources = ["dependencies/glad/src/glad.c"]
    sources += glob.glob("glue/**/*.cpp", recursive=True)
    sources += glob.glob("*.cpp", recursive=True)

    build = []
    build += compiler
    build += compiler_args
    build += set(linker_args)
    build += ["-D{}={}".format(*kv) for kv in defines.items()]
    build += sources

    print(" ".join(build))
    start = time.time()
    subprocess.run(build, stdout=sys.stdout, stderr=sys.stdout)
    stop = time.time()
    delta = stop - start
    adjusted = math.floor(delta * 100)/100
    print("Build time: {} second(s)".format(adjusted))

    if debug_build and renderdoc_build:
        print ("Rember to symlink \"renderdoc.h\" and \"librenderdoc.so\" into the project root!")


if __name__ == "__main__":
    assert(sys.version_info.major >= 3)
    assert(sys.platform == "linux")
    build_program()

