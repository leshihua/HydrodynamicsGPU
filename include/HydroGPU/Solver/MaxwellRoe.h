#pragma once

#include "HydroGPU/Solver/Roe.h"

namespace HydroGPU {
namespace Solver {

/*
Roe solver for Maxwell equations
*/
struct MaxwellRoe : public Roe {
	typedef Roe Super;

protected:	
	cl::Kernel addSourceKernel;

public:
	using Super::Super;
	virtual void init();

protected:
	virtual void createEquation();
	virtual std::vector<std::string> getProgramSources();
	virtual int getEigenTransformStructSize();
	virtual std::vector<std::string> getEigenProgramSources();
	virtual void calcDeriv(cl::Buffer derivBuffer);
};

}
}

