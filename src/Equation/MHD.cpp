#include "HydroGPU/Equation/MHD.h"
#include "HydroGPU/HydroGPUApp.h"
#include "HydroGPU/Solver/Solver.h"
#include "Common/File.h"
#include "Common/Exception.h"

namespace HydroGPU {
namespace Equation {

MHD::MHD(HydroGPU::Solver::Solver* solver_)
: Super(solver_)
{
	displayMethods = std::vector<std::string>{
		"DENSITY",
		"VELOCITY",
		"PRESSURE",
		"MAGNETIC_FIELD",
		"MAGNETIC_DIVERGENCE",
		"POTENTIAL"
	};

	//matches Equations/SelfGravitationBehavior 
	boundaryMethods = std::vector<std::string>{
		"PERIODIC",
		"MIRROR",
		"FREEFLOW"
	};

	states = {
		"DENSITY",
		"MOMENTUM_X",
		"MOMENTUM_Y",
		"MOMENTUM_Z",
		"MAGNETIC_FIELD_X",
		"MAGNETIC_FIELD_Y",
		"MAGNETIC_FIELD_Z",
		"ENERGY_TOTAL"
	};
}

void MHD::getProgramSources(std::vector<std::string>& sources) {
	Super::getProgramSources(sources);
	
	sources[0] += "#include \"HydroGPU/Shared/Common.h\"\n";	//for real's definition
	
	real gamma = 1.4f;
	solver->app->lua.ref()["gamma"] >> gamma;
	sources[0] += "constant real gamma = " + toNumericString<real>(gamma) + ";\n";

	real vaccuumPermeability = 1.f;
	solver->app->lua.ref()["vaccuumPermeability"] >> vaccuumPermeability;
	sources[0] += "constant real vaccuumPermeability = " + toNumericString<real>(vaccuumPermeability) + ";\n";
	sources[0] += "constant real sqrtVaccuumPermeability = " + toNumericString<real>(sqrt(vaccuumPermeability)) + ";\n";

	//for EulerMHDCommon.cl
	sources[0] += "#define MHD 1\n";

	sources.push_back(Common::File::read("MHDCommon.cl"));
	sources.push_back(Common::File::read("EulerMHDCommon.cl"));
}

int MHD::stateGetBoundaryKernelForBoundaryMethod(int dim, int stateIndex) {
	switch (solver->app->boundaryMethods(dim)) {
	case BOUNDARY_METHOD_PERIODIC:
		return BOUNDARY_KERNEL_PERIODIC;
		break;
	case BOUNDARY_METHOD_MIRROR:
		return (dim + 1 == stateIndex || dim + 4 == stateIndex) ? BOUNDARY_KERNEL_REFLECT : BOUNDARY_KERNEL_MIRROR;
		break;		
	case BOUNDARY_METHOD_FREEFLOW:
		return BOUNDARY_KERNEL_FREEFLOW;
		break;
	}
	throw Common::Exception() << "got an unknown boundary method " << solver->app->boundaryMethods(dim) << " for dim " << dim;
}

}
}
