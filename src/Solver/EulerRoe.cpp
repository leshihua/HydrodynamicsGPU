#include "HydroGPU/Equation/Euler.h"
#include "HydroGPU/Solver/EulerRoe.h"
#include "HydroGPU/HydroGPUApp.h"

namespace HydroGPU {
namespace Solver {

void EulerRoe::init() {
	Super::init();
	
	//all Euler and MHD systems also have a separate potential buffer...
	app->setArgs(calcEigenBasisKernel, eigenvaluesBuffer, eigenfieldsBuffer, stateBuffer, selfgrav->potentialBuffer);
}

void EulerRoe::createEquation() {
	equation = std::make_shared<HydroGPU::Equation::Euler>(this);
}

std::vector<std::string> EulerRoe::getProgramSources() {
	std::vector<std::string> sources = Super::getProgramSources();
	sources.push_back("#include \"EulerRoe.cl\"\n");
	return sources;
}

void EulerRoe::step() {
	Super::step();
	selfgrav->applyPotential();
}

}
}

