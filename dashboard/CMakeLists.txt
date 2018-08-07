cmake_minimum_required(VERSION 3.1.0)

project(dashboard)

# Find includes in corresponding build directories
set(CMAKE_INCLUDE_CURRENT_DIR ON)

# Instruct CMake to run moc automatically when needed
set(CMAKE_AUTOMOC ON)

# Find the QtWidgets library
find_package(Qt5Widgets CONFIG REQUIRED)

# Populate a CMake variable with the sources
set(dashboard_SRCS
	ISO9141.cpp
	OBDIIWorker.cpp
	SkinnyQGridLayout.cpp
	MainWindow.cpp
	MILCode.cpp
	port.cpp
	main.cpp
)

# Tell CMake to create the dashboard executable
add_executable(dashboard ${dashboard_SRCS})

# Compile in C++17
set_property(TARGET dashboard PROPERTY CXX_STANDARD 14)

# Use the Widgets module from Qt 5
target_link_libraries(dashboard Qt5::Widgets)
