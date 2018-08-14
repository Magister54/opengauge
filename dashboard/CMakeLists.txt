cmake_minimum_required(VERSION 3.1.0)

set(PROJECT "dashboard")

project(${PROJECT})
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wall -Wextra -fstrict-aliasing -pedantic -Wno-deprecated-declarations -Wno-unused-variable")

# Find includes in corresponding build directories
set(CMAKE_INCLUDE_CURRENT_DIR ON)

# Instruct CMake to run moc automatically when needed
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

# Find the QtWidgets library
find_package(Qt5 COMPONENTS Core Qml Quick Widgets REQUIRED)

# Add qrc file
qt5_add_resources(QT_RESOURCES src/qml.qrc)

# Tell CMake to create the executable
if(NOT DEFINED HEADERS)
    file(GLOB HEADERS src⁄*.h)
endif()
if(NOT DEFINED SOURCES)
    file(GLOB SOURCES src/*.cpp)
endif()
source_group("Header Files" FILES ${HEADERS})
source_group("Source Files" FILES ${SOURCES})
add_executable(${PROJECT} ${HEADERS} ${SOURCES} ${QT_RESOURCES})

# Compile in C++14
set_property(TARGET ${PROJECT} PROPERTY CXX_STANDARD 14)

# Use the Widgets module from Qt 5
target_link_libraries(${PROJECT} Qt5::Core Qt5::Qml Qt5::Quick Qt5::Widgets wiringPi)
