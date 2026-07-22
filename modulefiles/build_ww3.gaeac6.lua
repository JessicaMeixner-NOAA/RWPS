help([[
  This module loads libraries required for building and running UFS Weather Model 
  on the NOAA RDHPC machine Gaea C6 using Intel-2023.2.0.
]])

whatis([===[Loads libraries needed for building the UFS Weather Model on Gaea C6]===])

prepend_path("MODULEPATH", "/ncrc/proj/epic/spack-stack/c6/spack-stack-1.9.2/envs/ue-intel-2023.2.0/install/modulefiles/Core")
prepend_path("MODULEPATH", "/ncrc/proj/epic/spack-stack/c6/modulefiles")

stack_intel_ver=os.getenv("stack_intel_ver") or "2023.2.0"
load(pathJoin("stack-intel", stack_intel_ver))

stack_cray_mpich_ver=os.getenv("stack_cray_mpich_ver") or "8.1.30"
load(pathJoin("stack-cray-mpich", stack_cray_mpich_ver))

stack_python_ver=os.getenv("stack_python_ver") or "3.11.7"
load(pathJoin("stack-python", stack_python_ver))

cmake_ver=os.getenv("cmake_ver") or "3.27.9"
load(pathJoin("cmake", cmake_ver))

local ufs_modules = {
  {["jasper"]          = "2.0.32"},
  {["libpng"]          = "1.6.37"},
  {["hdf5"]            = "1.14.3"},
  {["netcdf-c"]        = "4.9.2"},
  {["netcdf-fortran"]  = "4.6.1"},
  {["parallelio"]      = "2.6.2"},
  {["esmf"]            = "8.8.0"},
  {["fms"]             = "2024.02"},
  {["bacio"]           = "2.4.1"},
  {["crtm"]            = "2.4.0.1"},
  {["g2"]              = "3.5.1"},
  {["g2tmpl"]          = "1.13.0"},
  {["ip"]              = "5.1.0"},
  {["sp"]              = "2.5.0"},
  {["w3emc"]           = "2.10.0"},
  {["gftl-shared"]     = "1.9.0"},
  {["mapl"]            = "2.53.4-esmf-8.8.0"},
  {["scotch"]          = "7.0.4"},
}

for i = 1, #ufs_modules do
  for name, default_version in pairs(ufs_modules[i]) do
    local env_version_name = string.gsub(name, "-", "_") .. "_ver"
    load(pathJoin(name, os.getenv(env_version_name) or default_version))
  end
end

load("zlib/1.2.13")

nccmp_ver=os.getenv("nccmp_ver") or "1.9.0.1"
load(pathJoin("nccmp", nccmp_ver))

unload("darshan-runtime")
unload("cray-libsci")

setenv("CC","cc")
setenv("CXX","CC")
setenv("FC","ftn")
setenv("CMAKE_Platform","gaeac6.intel")
