#pragma once

#include "HydroGPU/Solver.h"
#include "Profiler/Stat.h"
#include "Tensor/Vector.h"
#include <OpenCL/cl.hpp>
#include <vector>

struct HydroGPUApp;

struct BurgersSolver : public Solver {
	cl::Program program;
	cl::CommandQueue commands;
	
	cl::Buffer stateBuffer;
	cl::Buffer eigenvaluesBuffer;
	cl::Buffer eigenvectorsBuffer;
	cl::Buffer eigenvectorsInverseBuffer;
	cl::Buffer deltaQTildeBuffer;
	cl::Buffer fluxBuffer;
	cl::Buffer cflBuffer;
	cl::Buffer cflTimestepBuffer;
	
	cl::Kernel calcEigenBasisKernel;
	cl::Kernel calcCFLKernel;
	cl::Kernel calcDeltaQTildeKernel;
	cl::Kernel calcCFLMinReduceKernel;
	cl::Kernel calcCFLMinFinalKernel;
	cl::Kernel calcFluxKernel;
	cl::Kernel updateStateKernel;
	cl::Kernel convertToTexKernel;
	cl::Kernel addDropKernel;
	cl::Kernel addSourceKernel;
	
	struct EventProfileEntry {
		EventProfileEntry(std::string name_) : name(name_) {}
		std::string name;
		cl::Event clEvent;
		Profiler::Stat stat;
	};

	HydroGPUApp &app;

	EventProfileEntry calcEigenBasisEvent;
	EventProfileEntry calcCFLEvent;
	EventProfileEntry calcDeltaQTildeEvent;
	EventProfileEntry calcCFLMinReduceEvent;
	EventProfileEntry calcCFLMinFinalEvent;
	EventProfileEntry calcFluxEvent;
	EventProfileEntry updateStateEvent;
	EventProfileEntry addSourceEvent;
	std::vector<EventProfileEntry*> entries;

	cl::NDRange globalSize, localSize;

	cl_float2 addSourcePos, addSourceVel;
	
	real cfl;

	BurgersSolver(HydroGPUApp &app);
	virtual ~BurgersSolver();

	virtual void update();
	virtual void addDrop(Tensor::Vector<float,DIM> pos, Tensor::Vector<float,DIM> vel);
	virtual void screenshot();
};

