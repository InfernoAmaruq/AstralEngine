file (GLOB_RECURSE source_files
    "${CLEANUP_DIR}/*.c"
    "${CLEANUP_DIR}/*.cpp"
)

foreach(file ${source_files})
    file(REMOVE "${file}")
    message(STATUS "Cleanded file: ${file}")
endforeach()
