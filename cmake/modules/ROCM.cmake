# ROCM Module
if(USE_ROCM)
  find_rocm(${USE_ROCM} REQUIRED)
else(USE_ROCM)
  return()
endif()

###### Borrowed from MSHADOW project

include(CheckCXXCompilerFlag)
check_cxx_compiler_flag("-std=c++11"   SUPPORT_CXX11)

set(dgl_known_gpu_archs "gfx906")

################################################################################################
# A function for automatic detection of GPUs installed  (if autodetection is enabled)
# Usage:
#   dgl_detect_installed_gpus(out_variable)
function(dgl_detect_installed_gpus out_variable)
set(ROCM_gpu_detect_output "")
  if(NOT ROCM_gpu_detect_output)
    message(STATUS "Running GPU architecture autodetection")
    set(__rocmfile ${PROJECT_BINARY_DIR}/detect_rocm_archs.cpp)

    file(WRITE ${__rocmfile} ""
      "#include <cstdio>\n"
      "#include <iostream>\n"
      "using namespace std;\n"
      "int main()\n"
      "{\n"
      "  int count = 0;\n"
      "  if (hipSuccess != hipGetDeviceCount(&count)) { return -1; }\n"
      "  if (count == 0) { cerr << \"No rocm devices detected\" << endl; return -1; }\n"
      "  for (int device = 0; device < count; ++device)\n"
      "  {\n"
      "    hipDeviceProp prop;\n"
      "    if (hipSuccess == hipGetDeviceProperties(&prop, device))\n"
      "      std::printf(\"%d.%d \", prop.major, prop.minor);\n"
      "  }\n"
      "  return 0;\n"
      "}\n")
    if(MSVC)
      #find vcvarsall.bat and run it building msvc environment
      get_filename_component(MY_COMPILER_DIR ${CMAKE_CXX_COMPILER} DIRECTORY)
      find_file(MY_VCVARSALL_BAT vcvarsall.bat "${MY_COMPILER_DIR}/.." "${MY_COMPILER_DIR}/../..")
      execute_process(COMMAND ${MY_VCVARSALL_BAT} && ${ROCM_HIPHCC_EXECUTABLE} -arch sm_30 --run  ${__rocmfile}
                      WORKING_DIRECTORY "${PROJECT_BINARY_DIR}/CMakeFiles/"
                      RESULT_VARIABLE __hiphcc_res OUTPUT_VARIABLE __hiphcc_out
                      OUTPUT_STRIP_TRAILING_WHITESPACE)
    else()
      if(ROCM_LIBRARY_PATH)
        set(ROCM_LIBRARY_PATH "-L${ROCM_LIBRARY_PATH}")
      endif()
      execute_process(COMMAND ${ROCM_HIPHCC_EXECUTABLE} -arch sm_30 --run ${__rocmfile} ${ROCM_LINK_LIBRARY_PATH}
                      WORKING_DIRECTORY "${PROJECT_BINARY_DIR}/CMakeFiles/"
                      RESULT_VARIABLE __hiphcc_res OUTPUT_VARIABLE __hiphcc_out
                      OUTPUT_STRIP_TRAILING_WHITESPACE)
    endif()
    if(__hiphcc_res EQUAL 0)
      # hiphcc outputs text containing line breaks when building with MSVC.
      # The line below prevents CMake from inserting a variable with line
      # breaks in the cache
      message(STATUS "Found ROCM arch ${__hiphcc_out}")
      string(REGEX MATCH "([1-9].[0-9])" __hiphcc_out "${__hiphcc_out}")
      string(REPLACE "2.1" "2.1(2.0)" __hiphcc_out "${__hiphcc_out}")
      set(ROCM_gpu_detect_output ${__hiphcc_out} CACHE INTERNAL "Returned GPU architetures from mshadow_detect_gpus tool" FORCE)
    else()
      message(WARNING "Running GPU detection script with hiphcc failed: ${__hiphcc_out}")
    endif()
  endif()

  if(NOT ROCM_gpu_detect_output)
    message(WARNING "Automatic GPU detection failed. Building for all known architectures (${dgl_known_gpu_archs}).")
    set(${out_variable} ${dgl_known_gpu_archs} PARENT_SCOPE)
  else()
    set(${out_variable} ${ROCM_gpu_detect_output} PARENT_SCOPE)
  endif()
endfunction()


################################################################################################
# Function for selecting GPU arch flags for hiphcc based on ROCM_ARCH_NAME
# Usage:
#   dgl_select_hiphcc_arch_flags(out_variable)
function(dgl_select_hiphcc_arch_flags out_variable)
  # List of arch names
  set(__archs_names "Fermi" "Kepler" "Maxwell" "Pascal" "Volta" "All" "Manual")
  set(__archs_name_default "All")
  if(NOT CMAKE_CROSSCOMPILING)
    list(APPEND __archs_names "Auto")
    set(__archs_name_default "Auto")
  endif()

  # set ROCM_ARCH_NAME strings (so it will be seen as dropbox in CMake-Gui)
  set(ROCM_ARCH_NAME ${__archs_name_default} CACHE STRING "Select target NVIDIA GPU achitecture.")
  set_property( CACHE ROCM_ARCH_NAME PROPERTY STRINGS "" ${__archs_names} )
  mark_as_advanced(ROCM_ARCH_NAME)

  # verify ROCM_ARCH_NAME value
  if(NOT ";${__archs_names};" MATCHES ";${ROCM_ARCH_NAME};")
    string(REPLACE ";" ", " __archs_names "${__archs_names}")
    message(FATAL_ERROR "Only ${__archs_names} architeture names are supported.")
  endif()

  if(${ROCM_ARCH_NAME} STREQUAL "Manual")
    set(ROCM_ARCH_BIN ${dgl_known_gpu_archs} CACHE STRING "Specify 'real' GPU architectures to build binaries for, BIN(PTX) format is supported")
    set(ROCM_ARCH_PTX "50"                     CACHE STRING "Specify 'virtual' PTX architectures to build PTX intermediate code for")
    mark_as_advanced(ROCM_ARCH_BIN ROCM_ARCH_PTX)
  else()
    unset(ROCM_ARCH_BIN CACHE)
    unset(ROCM_ARCH_PTX CACHE)
  endif()

  if(${ROCM_ARCH_NAME} STREQUAL "Fermi")
    set(__rocm_arch_bin "20 21(20)")
  elseif(${ROCM_ARCH_NAME} STREQUAL "Kepler")
    set(__rocm_arch_bin "30 35")
  elseif(${ROCM_ARCH_NAME} STREQUAL "Maxwell")
    set(__rocm_arch_bin "50")
  elseif(${ROCM_ARCH_NAME} STREQUAL "Pascal")
    set(__rocm_arch_bin "60 61")
  elseif(${ROCM_ARCH_NAME} STREQUAL "Volta")
    set(__rocm_arch_bin "70")
  elseif(${ROCM_ARCH_NAME} STREQUAL "All")
    set(__rocm_arch_bin ${dgl_known_gpu_archs})
  elseif(${ROCM_ARCH_NAME} STREQUAL "Auto")
    dgl_detect_installed_gpus(__rocm_arch_bin)
  else()  # (${ROCM_ARCH_NAME} STREQUAL "Manual")
    set(__rocm_arch_bin ${ROCM_ARCH_BIN})
  endif()

  # remove dots and convert to lists
  string(REGEX REPLACE "\\." "" __rocm_arch_bin "${__rocm_arch_bin}")
  string(REGEX REPLACE "\\." "" __rocm_arch_ptx "${ROCM_ARCH_PTX}")
  string(REGEX MATCHALL "[0-9()]+" __rocm_arch_bin "${__rocm_arch_bin}")
  string(REGEX MATCHALL "[0-9]+"   __rocm_arch_ptx "${__rocm_arch_ptx}")
  mshadow_list_unique(__rocm_arch_bin __rocm_arch_ptx)

  set(__hiphcc_flags "")
  set(__hiphcc_archs_readable "")

  # Tell HIPHCC to add binaries for the specified GPUs
  foreach(__arch ${__rocm_arch_bin})
    if(__arch MATCHES "([0-9]+)\\(([0-9]+)\\)")
      # User explicitly specified PTX for the concrete BIN
      list(APPEND __hiphcc_flags -gencode arch=compute_${CMAKE_MATCH_2},code=sm_${CMAKE_MATCH_1})
      list(APPEND __hiphcc_archs_readable sm_${CMAKE_MATCH_1})
    else()
      # User didn't explicitly specify PTX for the concrete BIN, we assume PTX=BIN
      list(APPEND __hiphcc_flags -gencode arch=compute_${__arch},code=sm_${__arch})
      list(APPEND __hiphcc_archs_readable sm_${__arch})
    endif()
  endforeach()

  # Tell HIPHCC to add PTX intermediate code for the specified architectures
  foreach(__arch ${__rocm_arch_ptx})
    list(APPEND __hiphcc_flags -gencode arch=compute_${__arch},code=compute_${__arch})
    list(APPEND __hiphcc_archs_readable compute_${__arch})
  endforeach()

  string(REPLACE ";" " " __hiphcc_archs_readable "${__hiphcc_archs_readable}")
  set(${out_variable}          ${__hiphcc_flags}          PARENT_SCOPE)
  set(${out_variable}_readable ${__hiphcc_archs_readable} PARENT_SCOPE)
endfunction()

################################################################################################
# Short command for rocm comnpilation
# Usage:
#   dgl_rocm_compile(<objlist_variable> <rocm_files>)
macro(dgl_rocm_compile objlist_variable)
  foreach(var CMAKE_CXX_FLAGS CMAKE_CXX_FLAGS_RELEASE CMAKE_CXX_FLAGS_DEBUG)
    set(${var}_backup_in_rocm_compile_ "${${var}}")

    # we remove /EHa as it generates warnings under windows
    string(REPLACE "/EHa" "" ${var} "${${var}}")

  endforeach()
  if(UNIX OR APPLE)
    list(APPEND ROCM_HIPHCC_FLAGS -Xcompiler -fPIC)
  endif()

  if(APPLE)
    list(APPEND ROCM_HIPHCC_FLAGS -Xcompiler -Wno-unused-function)
  endif()

  set(ROCM_HIPHCC_FLAGS_DEBUG "${ROCM_HIPHCC_FLAGS_DEBUG} -G")

  if(MSVC)
    # disable noisy warnings:
    # 4819: The file contains a character that cannot be represented in the current code page (number).
    list(APPEND ROCM_HIPHCC_FLAGS -Xcompiler "/wd4819")
    foreach(flag_var
        CMAKE_CXX_FLAGS CMAKE_CXX_FLAGS_DEBUG CMAKE_CXX_FLAGS_RELEASE
        CMAKE_CXX_FLAGS_MINSIZEREL CMAKE_CXX_FLAGS_RELWITHDEBINFO)
      if(${flag_var} MATCHES "/MD")
        string(REGEX REPLACE "/MD" "/MT" ${flag_var} "${${flag_var}}")
      endif(${flag_var} MATCHES "/MD")
    endforeach(flag_var)
  endif()

  # If the build system is a container, make sure the hiphcc intermediate files
  # go into the build output area rather than in /tmp, which may run out of space
  if(IS_CONTAINER_BUILD)
    set(ROCM_HIPHCC_INTERMEDIATE_DIR "${CMAKE_CURRENT_BINARY_DIR}")
    message(STATUS "Container build enabled, so hiphcc intermediate files in: ${ROCM_HIPHCC_INTERMEDIATE_DIR}")
    list(APPEND ROCM_HIPHCC_FLAGS "--keep --keep-dir ${ROCM_HIPHCC_INTERMEDIATE_DIR}")
  endif()

  rocm_compile(rocm_objcs ${ARGN})

  foreach(var CMAKE_CXX_FLAGS CMAKE_CXX_FLAGS_RELEASE CMAKE_CXX_FLAGS_DEBUG)
    set(${var} "${${var}_backup_in_rocm_compile_}")
    unset(${var}_backup_in_rocm_compile_)
  endforeach()

  set(${objlist_variable} ${rocm_objcs})
endmacro()

################################################################################################
# Config rocm compilation.
# Usage:
#   dgl_config_rocm(<dgl_rocm_src>)
macro(dgl_config_rocm out_variable)
  if(NOT ROCM_FOUND)
    message(FATAL_ERROR "Cannot find ROCM.")
  endif()
  # always set the includedir when rocm is available
  # avoid global retrigger of cmake
	include_directories(${ROCM_INCLUDE_DIRS})

  add_definitions(-DDGL_USE_ROCM)

  file(GLOB_RECURSE DGL_ROCM_SRC
    src/array/rocm/*.cc
    src/array/rocm/*.cu
    src/kernel/rocm/*.cc
    src/kernel/rocm/*.cu
    src/runtime/rocm/*.cc
  )

  dgl_select_hiphcc_arch_flags(HIPHCC_FLAGS_ARCH)
  string(REPLACE ";" " " HIPHCC_FLAGS_ARCH "${HIPHCC_FLAGS_ARCH}")
  set(HIPHCC_FLAGS_EXTRA ${HIPHCC_FLAGS_ARCH})
  # for lambda support in moderngpu
  set(HIPHCC_FLAGS_EXTRA "${HIPHCC_FLAGS_EXTRA} --expt-extended-lambda")
  # suppress deprecated warning in moderngpu
  set(HIPHCC_FLAGS_EXTRA "${HIPHCC_FLAGS_EXTRA} -Wno-deprecated-declarations")
  message(STATUS "HIPHCC extra flags: ${HIPHCC_FLAGS_EXTRA}")
  set(ROCM_HIPHCC_FLAGS  "${ROCM_HIPHCC_FLAGS} ${HIPHCC_FLAGS_EXTRA}")
  list(APPEND CMAKE_HIP_FLAGS "${HIPHCC_FLAGS_EXTRA}")

  list(APPEND DGL_LINKER_LIBS
    ${ROCM_ROCM_LIBRARY} ${ROCM_ROCMRT_LIBRARY}
    ${ROCM_CUBLAS_LIBRARIES} ${ROCM_cusparse_LIBRARY})

  set(${out_variable} ${DGL_ROCM_SRC})
endmacro()
