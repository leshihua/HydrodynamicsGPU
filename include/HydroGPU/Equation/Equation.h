#pragma once

#include "HydroGPU/Shared/Common.h"	//real
#include "CLCommon/cl.hpp"
#include <vector>
#include <string>

namespace HydroGPU {
struct HydroGPUApp;
namespace Solver {
struct Solver;
}
namespace Equation {

struct Equation {
protected:
	HydroGPUApp* app;
public:
	std::vector<std::string> displayVariables;	//TODO: "scalarVariables"
	std::vector<std::string> vectorFieldVars;
	std::vector<std::string> boundaryMethods;
	std::vector<std::string> states;

	Equation(HydroGPUApp* app_);	
	virtual void getProgramSources(std::vector<std::string>& sources);
	virtual int stateGetBoundaryKernelForBoundaryMethod(int dim, int state, int minmax) = 0;
	std::string buildEnumCode(const std::string& prefix, const std::vector<std::string>& enumStrs);
	virtual void readStateCell(real* state, const real* source);
	virtual int numReadStateChannels();
	virtual std::string name() const = 0; 
	
	virtual void setupConvertToTexKernelArgs(cl::Kernel convertToTexKernel, Solver::Solver* solver);
	virtual void setupUpdateVectorFieldKernelArgs(cl::Kernel updateVectorFieldKernel, Solver::Solver* solver);
};

}
}
