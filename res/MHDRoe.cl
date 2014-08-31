/*
using the following:
"A Numerical Solution of Hyperbolic Partial Differential Equations", Trangenstein, 2007
"A multidimensional upwind scheme for magnetohydrodynamics" by Falle, Komissarov, Joarder, 1998
"A Solution-Adaptive Upwind Scheme for Ideal Magnetohydrodynamics" by Powell, Roe, Linde, Gombosi, Zeeuw, 1999

The eigenvalues of all three papers match up (with the exception of Powel 1999, which mentions Alfven waves being |B|/sqrt(rho) then defines the Alfven wave eigenvalue to be B/rho, no sqrt, no abs, but I'm pretty sure that's a typo)

The Alfven wave eigenvectors of the 199x papers and Trangenstein match up (with the exception of normalization, which Trangenstein neglects because he ignores computing the left-eigenvectors, which could absorb the normalization term) 

Now on to the fast and slow wave eigenvectors ... 


And the degeneracy of Bx=0:

Powell 1999 says something along the lines of "the system simply reduces to the Euler equation eigenvectors". By this they mean you'll have to write a separate case for Bx=0 with eigenvectors similar to those of the Euler equations'.
A subtle mention of what to do with those extra transverse magetic field values: add them to the pressure.
No mention that I noticed of how the system, on its own, will not reduce to the Euler equations, and in the absense of correctly calculated limits of ratios approaching zero, you will end up with the speed of sound squared in a few places where you should've got a zero.
The separate case for Bx=0 is necessary.

Trangenstein gives an exact example of the rhs eigenvectors in the Bx=0 case.  Thank you.
If only he gave left eigenvectors too.  Good thing most of them match with Powell and Falle.


Powell 1999 also doesn't state that "a" is the speed of sound.  Browsing through their sources clarifies the "a". 
*/

#include "HydroGPU/Shared/Common.h"

void calcEigenBasisSide(
	__global real* eigenvaluesBuffer,
	__global real* eigenvectorsBuffer,
	__global real* eigenvectorsInverseBuffer,
	const __global real* stateBuffer,
	const __global real* potentialBuffer,
	int side);

void calcEigenBasisSide(
	__global real* eigenvaluesBuffer,
	__global real* eigenvectorsBuffer,
	__global real* eigenvectorsInverseBuffer,
	const __global real* stateBuffer,
	const __global real* potentialBuffer,
	int side)
{
	int4 i = (int4)(get_global_id(0), get_global_id(1), get_global_id(2), 0);
	
	int index = INDEXV(i);
	int indexPrev = index - stepsize[side];
	int interfaceIndex = side + DIM * index;

	const __global real* stateL = stateBuffer + NUM_STATES * indexPrev;
	const __global real* stateR = stateBuffer + NUM_STATES * index;
	
	__global real* eigenvalues = eigenvaluesBuffer + NUM_STATES * interfaceIndex;
	__global real* eigenvectors = eigenvectorsBuffer + NUM_STATES * NUM_STATES * interfaceIndex;
	__global real* eigenvectorsInverse = eigenvectorsInverseBuffer + NUM_STATES * NUM_STATES * interfaceIndex;
	
	const real gammaMinusOne = gamma - 1.f;

	real densityL = stateL[STATE_DENSITY];
	real4 velocityL = VELOCITY(stateL);
	real4 magneticFieldL = (real4)(stateL[STATE_MAGNETIC_FIELD_X], stateL[STATE_MAGNETIC_FIELD_Y], stateL[STATE_MAGNETIC_FIELD_Z], 0.f);
	real magneticEnergyDensityL = .5f * dot(magneticFieldL, magneticFieldL) / vaccuumPermeability;
	real totalPlasmaEnergyDensityL = stateL[STATE_ENERGY_TOTAL];
	real totalHydroEnergyDensityL = totalPlasmaEnergyDensityL - magneticEnergyDensityL;
	real kineticEnergyDensityL = .5f * densityL * dot(velocityL, velocityL);
	real potentialEnergyDensityL = densityL * potentialBuffer[indexPrev];
	real internalEnergyDensityL = totalHydroEnergyDensityL - kineticEnergyDensityL - potentialEnergyDensityL;
	real pressureL = gammaMinusOne * internalEnergyDensityL;

	real densityR = stateR[STATE_DENSITY];
	real4 velocityR = VELOCITY(stateR);
	real4 magneticFieldR = (real4)(stateR[STATE_MAGNETIC_FIELD_X], stateR[STATE_MAGNETIC_FIELD_Y], stateR[STATE_MAGNETIC_FIELD_Z], 0.f);
	real magneticEnergyDensityR = .5f * dot(magneticFieldR, magneticFieldR) / vaccuumPermeability;
	real totalPlasmaEnergyDensityR = stateR[STATE_ENERGY_TOTAL];
	real totalHydroEnergyDensityR = totalPlasmaEnergyDensityR - magneticEnergyDensityR;
	real kineticEnergyDensityR = .5f * densityR * dot(velocityR, velocityR);
	real potentialEnergyDensityR = densityR * potentialBuffer[index];
	real internalEnergyDensityR = totalHydroEnergyDensityR - kineticEnergyDensityR - potentialEnergyDensityR;
	real pressureR = gammaMinusOne * internalEnergyDensityR;

	//3.5.2 "In this paper, a simple arithmetic averaging of the primitive variables is done to compute the interface state."
	real density = .5f * (densityL + densityR);
	real4 velocity = .5f * (velocityL + velocityR);
	real4 magneticField = .5f * (magneticFieldL + magneticFieldR);
	real pressure = .5f * (pressureL * pressureR);
	
#if DIM > 1
	if (side == 1) {
		// -90' rotation to put the y axis contents into the x axis
		velocity = (real4)(velocity.y, -velocity.x, velocity.z, 0.f);
		magneticField = (real4)(magneticField.y, -magneticField.x, magneticField.z, 0.f);
	} 
#if DIM > 2
	else if (side == 2) {
		//-90' rotation to put the z axis in the x axis
		velocity = (real4)(velocity.z, velocity.y, -velocity.x, 0.f);
		magneticField = (real4)(magneticField.z, magneticField.y, -magneticField.x, 0.f);
	}
#endif
#endif

	real velocitySq = dot(velocity, velocity);
	real sqrtDensity = sqrt(density);
	real speedOfSound = sqrt(gamma * pressure / density);
	real speedOfSoundSq = speedOfSound * speedOfSound;
	
	real magneticFieldSq = dot(magneticField, magneticField);
	real magneticFieldXSq = magneticField.x * magneticField.x;
	
	real AlfvenSpeed = fabs(magneticField.x) / sqrtDensity;
	real starSpeedSq = .5f * (speedOfSoundSq + magneticFieldSq / density);
	real discr = starSpeedSq * starSpeedSq - speedOfSoundSq * magneticFieldXSq / density;
	real tmp = sqrt(discr);
	real fastSpeedSq = starSpeedSq + tmp;
	real fastSpeed = sqrt(fastSpeedSq);
	real slowSpeedSq = starSpeedSq - tmp;
	real slowSpeed = sqrt(slowSpeedSq);
	
	real sgnBx;
	if (magneticField.x > 0.f) {
		sgnBx = 1.f;
	} else {
		sgnBx = -1.f;
	}

	real deltaSlow = density * slowSpeedSq - magneticFieldXSq;
	real deltaFast = density * fastSpeedSq - magneticFieldXSq;

	//eigenvalues

	eigenvalues[0] = velocity.x - fastSpeed;
	eigenvalues[1] = velocity.x - AlfvenSpeed;
	eigenvalues[2] = velocity.x - slowSpeed;
	eigenvalues[3] = velocity.x;
	eigenvalues[4] = velocity.x;
	eigenvalues[5] = velocity.x + slowSpeed;
	eigenvalues[6] = velocity.x + AlfvenSpeed;
	eigenvalues[7] = velocity.x + fastSpeed;


	real magneticFieldTSq = magneticField.y * magneticField.y + magneticField.z * magneticField.z;
	real magneticFieldT = sqrt(magneticFieldTSq);

#define M_SQRT_1_2	0.7071067811865475727373109293694142252206802368164f

#define DEBUG_INDEX		512

	//matrices are stored as A_ij = A[i + height * j]
	
	//eigenvectors
	real eigenvectorsWrtPrimitives[NUM_STATES * NUM_STATES];
	
	//eigenvectors inverse
	real eigenvectorsInverseWrtPrimitives[NUM_STATES * NUM_STATES];


	if (fabs(magneticField.x) < 1e-7f) {	//magnetic field has no velocity component

if (index == DEBUG_INDEX) {
printf("zero magnetic field in normal direction\n");
}

		//alfven speed is zero, slow speed is zero
		//fast speed is almost the speed of sound ... with the tangent magnetism mixed in there

/*
cf^2 = c*^2 + sqrt(c*^4 - c^2 Bx^2 / rho)
c*^2 = 1/2 (c^2 + B^2 / rho)
r_11 = (rho * cf^2 - B^2) / c^2

when Bx = 0
cf^2 = c*^2 + sqrt(c*^4)
cf^2 = c*^2 + c*^2
cf^2 = 2 * c*^2

c*^2 = 1/2 (c^2 + (By^2 + Bz^2) / rho)
cf^2 = c^2 + (By^2 + Bz^2) / rho

r_11 = (rho * cf^2 - By^2 - Bz^2) / c^2
r_11 = (rho * (c^2 + (By^2 + Bz^2) / rho) - By^2 - Bz^2) / c^2
r_11 = (rho * c^2 + By^2 + Bz^2 - By^2 - Bz^2) / c^2
r_11 = rho * c^2 / c^2
r_11 = rho
*/

		//fast magnetoacoustic col 
		eigenvectorsWrtPrimitives[0 + NUM_STATES * 0] = density;
		eigenvectorsWrtPrimitives[1 + NUM_STATES * 0] = -fastSpeed;
		eigenvectorsWrtPrimitives[2 + NUM_STATES * 0] = 0.f;
		eigenvectorsWrtPrimitives[3 + NUM_STATES * 0] = 0.f;
		eigenvectorsWrtPrimitives[4 + NUM_STATES * 0] = 0.f;
		eigenvectorsWrtPrimitives[5 + NUM_STATES * 0] = magneticField.y;
		eigenvectorsWrtPrimitives[6 + NUM_STATES * 0] = magneticField.z;
		eigenvectorsWrtPrimitives[7 + NUM_STATES * 0] = density * speedOfSoundSq;
		//Alfven col
		eigenvectorsWrtPrimitives[0 + NUM_STATES * 1] = 1.f;
		eigenvectorsWrtPrimitives[1 + NUM_STATES * 1] = 0.f;
		eigenvectorsWrtPrimitives[2 + NUM_STATES * 1] = 0.f;
		eigenvectorsWrtPrimitives[3 + NUM_STATES * 1] = 0.f;
		eigenvectorsWrtPrimitives[4 + NUM_STATES * 1] = 0.f;
		eigenvectorsWrtPrimitives[5 + NUM_STATES * 1] = 0.f;
		eigenvectorsWrtPrimitives[6 + NUM_STATES * 1] = 0.f;
		eigenvectorsWrtPrimitives[7 + NUM_STATES * 1] = 0.f;
		//slow magnetoacoustic col
		eigenvectorsWrtPrimitives[0 + NUM_STATES * 2] = 0.f;
		eigenvectorsWrtPrimitives[1 + NUM_STATES * 2] = 0.f;
		eigenvectorsWrtPrimitives[2 + NUM_STATES * 2] = 1.f;
		eigenvectorsWrtPrimitives[3 + NUM_STATES * 2] = 0.f;
		eigenvectorsWrtPrimitives[4 + NUM_STATES * 2] = 0.f;
		eigenvectorsWrtPrimitives[5 + NUM_STATES * 2] = 0.f;
		eigenvectorsWrtPrimitives[6 + NUM_STATES * 2] = 0.f;
		eigenvectorsWrtPrimitives[7 + NUM_STATES * 2] = 0.f;
		//entropy col
		eigenvectorsWrtPrimitives[0 + NUM_STATES * 3] = 0.f;
		eigenvectorsWrtPrimitives[1 + NUM_STATES * 3] = 0.f; 
		eigenvectorsWrtPrimitives[2 + NUM_STATES * 3] = 0.f;
		eigenvectorsWrtPrimitives[3 + NUM_STATES * 3] = 1.f;
		eigenvectorsWrtPrimitives[4 + NUM_STATES * 3] = 0.f;
		eigenvectorsWrtPrimitives[5 + NUM_STATES * 3] = 0.f;
		eigenvectorsWrtPrimitives[6 + NUM_STATES * 3] = 0.f;
		eigenvectorsWrtPrimitives[7 + NUM_STATES * 3] = 0.f;	
		//divergence col 
		eigenvectorsWrtPrimitives[0 + NUM_STATES * 4] = 0.f;
		eigenvectorsWrtPrimitives[1 + NUM_STATES * 4] = 0.f;
		eigenvectorsWrtPrimitives[2 + NUM_STATES * 4] = 0.f;
		eigenvectorsWrtPrimitives[3 + NUM_STATES * 4] = 0.f;
		eigenvectorsWrtPrimitives[4 + NUM_STATES * 4] = 1.f;
		eigenvectorsWrtPrimitives[5 + NUM_STATES * 4] = 0.f;
		eigenvectorsWrtPrimitives[6 + NUM_STATES * 4] = 0.f;
		eigenvectorsWrtPrimitives[7 + NUM_STATES * 4] = 0.f;
		//slow magnetoacoustic col
		eigenvectorsWrtPrimitives[0 + NUM_STATES * 5] = 0.f;
		eigenvectorsWrtPrimitives[1 + NUM_STATES * 5] = 0.f;
		eigenvectorsWrtPrimitives[2 + NUM_STATES * 5] = 0.f;
		eigenvectorsWrtPrimitives[3 + NUM_STATES * 5] = 0.f;
		eigenvectorsWrtPrimitives[4 + NUM_STATES * 5] = 0.f;
		eigenvectorsWrtPrimitives[5 + NUM_STATES * 5] = 1.f;
		eigenvectorsWrtPrimitives[6 + NUM_STATES * 5] = 0.f;
		eigenvectorsWrtPrimitives[7 + NUM_STATES * 5] = -magneticField.y;
		//Alfven col
		eigenvectorsWrtPrimitives[0 + NUM_STATES * 6] = 0.f;
		eigenvectorsWrtPrimitives[1 + NUM_STATES * 6] = 0.f;
		eigenvectorsWrtPrimitives[2 + NUM_STATES * 6] = 0.f;
		eigenvectorsWrtPrimitives[3 + NUM_STATES * 6] = 0.f;
		eigenvectorsWrtPrimitives[4 + NUM_STATES * 6] = 0.f;
		eigenvectorsWrtPrimitives[5 + NUM_STATES * 6] = 0.f;
		eigenvectorsWrtPrimitives[6 + NUM_STATES * 6] = 1.f;
		eigenvectorsWrtPrimitives[7 + NUM_STATES * 6] = -magneticField.z;
		//fast magnetoacoustic col
		eigenvectorsWrtPrimitives[0 + NUM_STATES * 7] = density;
		eigenvectorsWrtPrimitives[1 + NUM_STATES * 7] = fastSpeed;
		eigenvectorsWrtPrimitives[2 + NUM_STATES * 7] = 0.f;
		eigenvectorsWrtPrimitives[3 + NUM_STATES * 7] = 0.f;
		eigenvectorsWrtPrimitives[4 + NUM_STATES * 7] = 0.f;
		eigenvectorsWrtPrimitives[5 + NUM_STATES * 7] = magneticField.y;
		eigenvectorsWrtPrimitives[6 + NUM_STATES * 7] = magneticField.z;
		eigenvectorsWrtPrimitives[7 + NUM_STATES * 7] = density * speedOfSoundSq;

/*
A : matrix(
[rho,1,0,0,0,0,0,rho],
[-sqrt(c^2+(By^2+Bz^2)/rho),0,0,0,0,0,0,sqrt(c^2+(By^2+Bz^2)/rho)],
[0,0,1,0,0,0,0,0],
[0,0,0,1,0,0,0,0],
[0,0,0,0,1,0,0,0],
[By,0,0,0,0,1,0,By],
[Bz,0,0,0,0,0,1,Bz],
[rho * c^2,0,0,0,0,-By,-Bz,rho * c^2]);

invert(A);
...gives  << Expression too long to display! >>

...so I removed the 3-5 cols and rows that was identity anyways.

A : matrix(
[rho,1,0,0,rho],
[-cf,0,0,0,cf],
[By,0,1,0,By],
[Bz,0,0,1,Bz],
[rho * c^2,0,-By,-Bz,rho * c^2]);

determinant(A);
...gives 2*cf*(c^2*rho+Bz^2+By^2)

invert(A) * determinant(A)$
ratsimp(%);

...gives...
matrix(
[0,−c^2*rho−Bz^2−By^2,By*cf,Bz*cf,cf],
[2*c^2*cf*rho+(2*Bz^2+2*By^2)*cf,0,−2*By*cf*rho,−2*Bz*cf*rho,−2*cf*rho],
[0,0,2*c^2*cf*rho+2*Bz^2*cf,−2*By*Bz*cf,−2*By*cf],
[0,0,−2*By*Bz*cf,2*c^2*cf*rho+2*By^2*cf,−2*Bz*cf],
[0,c^2*rho+Bz^2+By^2,By*cf,Bz*cf,cf])

...which is our left eigenvector matrix (with the identity re-inserted into cols and rows 3-5)

*/
		//factored out the determinant
		real normalization = 1.f / (4.f * density * fastSpeed * starSpeedSq);

		//fast magnetoacoustic row
		eigenvectorsInverseWrtPrimitives[0 + NUM_STATES * 0] = 0.f;
		eigenvectorsInverseWrtPrimitives[0 + NUM_STATES * 1] = -.5f / fastSpeed;
		eigenvectorsInverseWrtPrimitives[0 + NUM_STATES * 2] = 0.f;
		eigenvectorsInverseWrtPrimitives[0 + NUM_STATES * 3] = 0.f;
		eigenvectorsInverseWrtPrimitives[0 + NUM_STATES * 4] = 0.f;
		eigenvectorsInverseWrtPrimitives[0 + NUM_STATES * 5] = normalization * fastSpeed * magneticField.y;
		eigenvectorsInverseWrtPrimitives[0 + NUM_STATES * 6] = normalization * fastSpeed * magneticField.z;
		eigenvectorsInverseWrtPrimitives[0 + NUM_STATES * 7] = normalization * fastSpeed;
		//Alfven row
		eigenvectorsInverseWrtPrimitives[1 + NUM_STATES * 0] = 1.f;
		eigenvectorsInverseWrtPrimitives[1 + NUM_STATES * 1] = 0.f;
		eigenvectorsInverseWrtPrimitives[1 + NUM_STATES * 2] = 0.f;
		eigenvectorsInverseWrtPrimitives[1 + NUM_STATES * 3] = 0.f;
		eigenvectorsInverseWrtPrimitives[1 + NUM_STATES * 4] = 0.f;
		eigenvectorsInverseWrtPrimitives[1 + NUM_STATES * 5] = normalization * -2.f * fastSpeed * density * magneticField.y;
		eigenvectorsInverseWrtPrimitives[1 + NUM_STATES * 6] = normalization * -2.f * fastSpeed * density * magneticField.z;
		eigenvectorsInverseWrtPrimitives[1 + NUM_STATES * 7] = normalization * -2.f * fastSpeed * density;
		//slow magnetoacoustic row
		eigenvectorsInverseWrtPrimitives[2 + NUM_STATES * 0] = 0.f;
		eigenvectorsInverseWrtPrimitives[2 + NUM_STATES * 1] = 0.f;
		eigenvectorsInverseWrtPrimitives[2 + NUM_STATES * 2] = 1.f;
		eigenvectorsInverseWrtPrimitives[2 + NUM_STATES * 3] = 0.f;
		eigenvectorsInverseWrtPrimitives[2 + NUM_STATES * 4] = 0.f;
		eigenvectorsInverseWrtPrimitives[2 + NUM_STATES * 5] = 0.f;
		eigenvectorsInverseWrtPrimitives[2 + NUM_STATES * 6] = 0.f;
		eigenvectorsInverseWrtPrimitives[2 + NUM_STATES * 7] = 0.f;
		//entropy row
		eigenvectorsInverseWrtPrimitives[3 + NUM_STATES * 0] = 0.f;
		eigenvectorsInverseWrtPrimitives[3 + NUM_STATES * 1] = 0.f;
		eigenvectorsInverseWrtPrimitives[3 + NUM_STATES * 2] = 0.f;
		eigenvectorsInverseWrtPrimitives[3 + NUM_STATES * 3] = 1.f;
		eigenvectorsInverseWrtPrimitives[3 + NUM_STATES * 4] = 0.f;
		eigenvectorsInverseWrtPrimitives[3 + NUM_STATES * 5] = 0.f;
		eigenvectorsInverseWrtPrimitives[3 + NUM_STATES * 6] = 0.f;
		eigenvectorsInverseWrtPrimitives[3 + NUM_STATES * 7] = 0.f;
		//divergence row
		eigenvectorsInverseWrtPrimitives[4 + NUM_STATES * 0] = 0.f;
		eigenvectorsInverseWrtPrimitives[4 + NUM_STATES * 1] = 0.f;
		eigenvectorsInverseWrtPrimitives[4 + NUM_STATES * 2] = 0.f;
		eigenvectorsInverseWrtPrimitives[4 + NUM_STATES * 3] = 0.f;
		eigenvectorsInverseWrtPrimitives[4 + NUM_STATES * 4] = 1.f;
		eigenvectorsInverseWrtPrimitives[4 + NUM_STATES * 5] = 0.f;
		eigenvectorsInverseWrtPrimitives[4 + NUM_STATES * 6] = 0.f;
		eigenvectorsInverseWrtPrimitives[4 + NUM_STATES * 7] = 0.f;
		//slow magnetoacoustic row
		eigenvectorsInverseWrtPrimitives[5 + NUM_STATES * 0] = 0.f;
		eigenvectorsInverseWrtPrimitives[5 + NUM_STATES * 1] = 0.f;
		eigenvectorsInverseWrtPrimitives[5 + NUM_STATES * 2] = 0.f;
		eigenvectorsInverseWrtPrimitives[5 + NUM_STATES * 3] = 0.f;
		eigenvectorsInverseWrtPrimitives[5 + NUM_STATES * 4] = 0.f;
		eigenvectorsInverseWrtPrimitives[5 + NUM_STATES * 5] = normalization * fastSpeed * 2.f * (speedOfSoundSq * density + magneticField.z * magneticField.z);
		eigenvectorsInverseWrtPrimitives[5 + NUM_STATES * 6] = normalization * fastSpeed * 2.f * -magneticField.y * magneticField.z;
		eigenvectorsInverseWrtPrimitives[5 + NUM_STATES * 7] = normalization * fastSpeed * 2.f * -magneticField.y;
		//Alfven row
		eigenvectorsInverseWrtPrimitives[6 + NUM_STATES * 0] = 0.f;
		eigenvectorsInverseWrtPrimitives[6 + NUM_STATES * 1] = 0.f;
		eigenvectorsInverseWrtPrimitives[6 + NUM_STATES * 2] = 0.f;
		eigenvectorsInverseWrtPrimitives[6 + NUM_STATES * 3] = 0.f;
		eigenvectorsInverseWrtPrimitives[6 + NUM_STATES * 4] = 0.f;
		eigenvectorsInverseWrtPrimitives[6 + NUM_STATES * 5] = normalization * fastSpeed * 2.f * -magneticField.y * magneticField.z;
		eigenvectorsInverseWrtPrimitives[6 + NUM_STATES * 6] = normalization * fastSpeed * 2.f * (speedOfSoundSq * density + magneticField.y * magneticField.y);
		eigenvectorsInverseWrtPrimitives[6 + NUM_STATES * 7] = normalization * fastSpeed * 2.f * -magneticField.z;
		//fast magnetoacoustic row
		eigenvectorsInverseWrtPrimitives[7 + NUM_STATES * 0] = 0.f;
		eigenvectorsInverseWrtPrimitives[7 + NUM_STATES * 1] = .5f / fastSpeed;
		eigenvectorsInverseWrtPrimitives[7 + NUM_STATES * 2] = 0.f;
		eigenvectorsInverseWrtPrimitives[7 + NUM_STATES * 3] = 0.f;
		eigenvectorsInverseWrtPrimitives[7 + NUM_STATES * 4] = 0.f;
		eigenvectorsInverseWrtPrimitives[7 + NUM_STATES * 5] = normalization * fastSpeed * magneticField.y;
		eigenvectorsInverseWrtPrimitives[7 + NUM_STATES * 6] = normalization * fastSpeed * magneticField.z;
		eigenvectorsInverseWrtPrimitives[7 + NUM_STATES * 7] = normalization * fastSpeed;
	
	} else {	//magnetic field has a velocity component
	
if (index == DEBUG_INDEX) {
printf("non-zero magnetic field in normal direction\n");
}

		if (fabs(magneticFieldT) < 1e-7f) {

			//fast magnetoacoustic col 
			eigenvectorsWrtPrimitives[0 + NUM_STATES * 0] = (fastSpeedSq * density - magneticFieldXSq) / speedOfSoundSq;
			eigenvectorsWrtPrimitives[1 + NUM_STATES * 0] = -(fastSpeedSq * density - magneticFieldXSq) / (density * fastSpeed);
			eigenvectorsWrtPrimitives[2 + NUM_STATES * 0] = 0.f;
			eigenvectorsWrtPrimitives[3 + NUM_STATES * 0] = 0.f;
			eigenvectorsWrtPrimitives[4 + NUM_STATES * 0] = 0.f;
			eigenvectorsWrtPrimitives[5 + NUM_STATES * 0] = 0.f;
			eigenvectorsWrtPrimitives[6 + NUM_STATES * 0] = 0.f;
			eigenvectorsWrtPrimitives[7 + NUM_STATES * 0] = fastSpeedSq * density - magneticFieldXSq;
			//Alfven col
			eigenvectorsWrtPrimitives[0 + NUM_STATES * 1] = 0.f;
			eigenvectorsWrtPrimitives[1 + NUM_STATES * 1] = 0.f;
			eigenvectorsWrtPrimitives[2 + NUM_STATES * 1] = 0.f;
			eigenvectorsWrtPrimitives[3 + NUM_STATES * 1] = 0.f;
			eigenvectorsWrtPrimitives[4 + NUM_STATES * 1] = 0.f;
			eigenvectorsWrtPrimitives[5 + NUM_STATES * 1] = 0.f;
			eigenvectorsWrtPrimitives[6 + NUM_STATES * 1] = 0.f;
			eigenvectorsWrtPrimitives[7 + NUM_STATES * 1] = 0.f;
			//slow magnetoacoustic col
			eigenvectorsWrtPrimitives[0 + NUM_STATES * 2] = (slowSpeedSq * density - magneticFieldXSq) / speedOfSoundSq; 
			eigenvectorsWrtPrimitives[1 + NUM_STATES * 2] = -(slowSpeedSq * density - magneticFieldXSq) / (density * slowSpeed);
			eigenvectorsWrtPrimitives[2 + NUM_STATES * 2] = 0.f;
			eigenvectorsWrtPrimitives[3 + NUM_STATES * 2] = 0.f;
			eigenvectorsWrtPrimitives[4 + NUM_STATES * 2] = 0.f;
			eigenvectorsWrtPrimitives[5 + NUM_STATES * 2] = 0.f;
			eigenvectorsWrtPrimitives[6 + NUM_STATES * 2] = 0.f;
			eigenvectorsWrtPrimitives[7 + NUM_STATES * 2] = slowSpeedSq * density - magneticFieldXSq;
			//entropy col
			eigenvectorsWrtPrimitives[0 + NUM_STATES * 3] = 1.f;
			eigenvectorsWrtPrimitives[1 + NUM_STATES * 3] = 0.f; 
			eigenvectorsWrtPrimitives[2 + NUM_STATES * 3] = 0.f;
			eigenvectorsWrtPrimitives[3 + NUM_STATES * 3] = 0.f;
			eigenvectorsWrtPrimitives[4 + NUM_STATES * 3] = 0.f;
			eigenvectorsWrtPrimitives[5 + NUM_STATES * 3] = 0.f;
			eigenvectorsWrtPrimitives[6 + NUM_STATES * 3] = 0.f;
			eigenvectorsWrtPrimitives[7 + NUM_STATES * 3] = 0.f;
			//divergence col 
			eigenvectorsWrtPrimitives[0 + NUM_STATES * 4] = 0.f;
			eigenvectorsWrtPrimitives[1 + NUM_STATES * 4] = 0.f;
			eigenvectorsWrtPrimitives[2 + NUM_STATES * 4] = 0.f;
			eigenvectorsWrtPrimitives[3 + NUM_STATES * 4] = 0.f;
			eigenvectorsWrtPrimitives[4 + NUM_STATES * 4] = 1.f;
			eigenvectorsWrtPrimitives[5 + NUM_STATES * 4] = 0.f;
			eigenvectorsWrtPrimitives[6 + NUM_STATES * 4] = 0.f;
			eigenvectorsWrtPrimitives[7 + NUM_STATES * 4] = 0.f;
			//slow magnetoacoustic col
			eigenvectorsWrtPrimitives[0 + NUM_STATES * 5] = (slowSpeedSq * density - magneticFieldXSq) / speedOfSoundSq;
			eigenvectorsWrtPrimitives[1 + NUM_STATES * 5] = (slowSpeedSq * density - magneticFieldXSq) / (density * slowSpeed);
			eigenvectorsWrtPrimitives[2 + NUM_STATES * 5] = 0.f;
			eigenvectorsWrtPrimitives[3 + NUM_STATES * 5] = 0.f;
			eigenvectorsWrtPrimitives[4 + NUM_STATES * 5] = 0.f;
			eigenvectorsWrtPrimitives[5 + NUM_STATES * 5] = 0.f;
			eigenvectorsWrtPrimitives[6 + NUM_STATES * 5] = 0.f;
			eigenvectorsWrtPrimitives[7 + NUM_STATES * 5] = slowSpeedSq * density - magneticFieldXSq;
			//Alfven col
			eigenvectorsWrtPrimitives[0 + NUM_STATES * 6] = 0.f;
			eigenvectorsWrtPrimitives[1 + NUM_STATES * 6] = 0.f;
			eigenvectorsWrtPrimitives[2 + NUM_STATES * 6] = 0.f;
			eigenvectorsWrtPrimitives[3 + NUM_STATES * 6] = 0.f;
			eigenvectorsWrtPrimitives[4 + NUM_STATES * 6] = 0.f;
			eigenvectorsWrtPrimitives[5 + NUM_STATES * 6] = 0.f;
			eigenvectorsWrtPrimitives[6 + NUM_STATES * 6] = 0.f;
			eigenvectorsWrtPrimitives[7 + NUM_STATES * 6] = 0.f;
			//fast magnetoacoustic col
			eigenvectorsWrtPrimitives[0 + NUM_STATES * 7] = (fastSpeedSq * density - magneticFieldXSq) / speedOfSoundSq;
			eigenvectorsWrtPrimitives[1 + NUM_STATES * 7] = (fastSpeedSq * density - magneticFieldXSq) / (density * fastSpeed);
			eigenvectorsWrtPrimitives[2 + NUM_STATES * 7] = 0.f;
			eigenvectorsWrtPrimitives[3 + NUM_STATES * 7] = 0.f;
			eigenvectorsWrtPrimitives[4 + NUM_STATES * 7] = 0.f;
			eigenvectorsWrtPrimitives[5 + NUM_STATES * 7] = 0.f;
			eigenvectorsWrtPrimitives[6 + NUM_STATES * 7] = 0.f;
			eigenvectorsWrtPrimitives[7 + NUM_STATES * 7] = fastSpeedSq * density - magneticFieldXSq;

			//fast magnetoacoustic row
			eigenvectorsInverseWrtPrimitives[0 + NUM_STATES * 0] = 0.f;
			eigenvectorsInverseWrtPrimitives[0 + NUM_STATES * 1] = -fastSpeed;
			eigenvectorsInverseWrtPrimitives[0 + NUM_STATES * 2] = magneticField.x * magneticField.y * fastSpeed / deltaFast;
			eigenvectorsInverseWrtPrimitives[0 + NUM_STATES * 3] = magneticField.x * magneticField.z * fastSpeed / deltaFast;
			eigenvectorsInverseWrtPrimitives[0 + NUM_STATES * 4] = 0.f;
			eigenvectorsInverseWrtPrimitives[0 + NUM_STATES * 5] = fastSpeedSq * magneticField.y / deltaFast;
			eigenvectorsInverseWrtPrimitives[0 + NUM_STATES * 6] = fastSpeedSq * magneticField.z / deltaFast;
			eigenvectorsInverseWrtPrimitives[0 + NUM_STATES * 7] = 1.f / density;
			//Alfven row
			eigenvectorsInverseWrtPrimitives[1 + NUM_STATES * 0] = 0.f;
			eigenvectorsInverseWrtPrimitives[1 + NUM_STATES * 1] = 0.f;
			eigenvectorsInverseWrtPrimitives[1 + NUM_STATES * 2] = sgnBx * magneticField.z;
			eigenvectorsInverseWrtPrimitives[1 + NUM_STATES * 3] = sgnBx * -magneticField.y;
			eigenvectorsInverseWrtPrimitives[1 + NUM_STATES * 4] = 0.f;
			eigenvectorsInverseWrtPrimitives[1 + NUM_STATES * 5] = magneticField.z / sqrtDensity;
			eigenvectorsInverseWrtPrimitives[1 + NUM_STATES * 6] = -magneticField.y / sqrtDensity;
			eigenvectorsInverseWrtPrimitives[1 + NUM_STATES * 7] = 0.f;
			//slow magnetoacoustic row
			eigenvectorsInverseWrtPrimitives[2 + NUM_STATES * 0] = 0.f;
			eigenvectorsInverseWrtPrimitives[2 + NUM_STATES * 1] = -slowSpeed;
			eigenvectorsInverseWrtPrimitives[2 + NUM_STATES * 2] = magneticField.x * magneticField.y * slowSpeed / deltaSlow;
			eigenvectorsInverseWrtPrimitives[2 + NUM_STATES * 3] = magneticField.x * magneticField.z * slowSpeed / deltaSlow;
			eigenvectorsInverseWrtPrimitives[2 + NUM_STATES * 4] = 0.f;
			eigenvectorsInverseWrtPrimitives[2 + NUM_STATES * 5] = slowSpeedSq * magneticField.y / deltaSlow;
			eigenvectorsInverseWrtPrimitives[2 + NUM_STATES * 6] = slowSpeedSq * magneticField.z / deltaSlow;
			eigenvectorsInverseWrtPrimitives[2 + NUM_STATES * 7] = 1.f / density;
			//entropy row
			eigenvectorsInverseWrtPrimitives[3 + NUM_STATES * 0] = 1.f;
			eigenvectorsInverseWrtPrimitives[3 + NUM_STATES * 1] = 0.f;
			eigenvectorsInverseWrtPrimitives[3 + NUM_STATES * 2] = 0.f;
			eigenvectorsInverseWrtPrimitives[3 + NUM_STATES * 3] = 0.f;
			eigenvectorsInverseWrtPrimitives[3 + NUM_STATES * 4] = 0.f;
			eigenvectorsInverseWrtPrimitives[3 + NUM_STATES * 5] = 0.f;
			eigenvectorsInverseWrtPrimitives[3 + NUM_STATES * 6] = 0.f;
			eigenvectorsInverseWrtPrimitives[3 + NUM_STATES * 7] = -1.f / speedOfSoundSq;
			//divergence row
			eigenvectorsInverseWrtPrimitives[4 + NUM_STATES * 0] = 0.f;
			eigenvectorsInverseWrtPrimitives[4 + NUM_STATES * 1] = 0.f;
			eigenvectorsInverseWrtPrimitives[4 + NUM_STATES * 2] = 0.f;
			eigenvectorsInverseWrtPrimitives[4 + NUM_STATES * 3] = 0.f;
			eigenvectorsInverseWrtPrimitives[4 + NUM_STATES * 4] = 1.f;
			eigenvectorsInverseWrtPrimitives[4 + NUM_STATES * 5] = 0.f;
			eigenvectorsInverseWrtPrimitives[4 + NUM_STATES * 6] = 0.f;
			eigenvectorsInverseWrtPrimitives[4 + NUM_STATES * 7] = 0.f;
			//slow magnetoacoustic row
			eigenvectorsInverseWrtPrimitives[5 + NUM_STATES * 0] = 0.f;
			eigenvectorsInverseWrtPrimitives[5 + NUM_STATES * 1] = slowSpeed;
			eigenvectorsInverseWrtPrimitives[5 + NUM_STATES * 2] = -magneticField.x * magneticField.y * slowSpeed / deltaSlow;
			eigenvectorsInverseWrtPrimitives[5 + NUM_STATES * 3] = -magneticField.x * magneticField.z * slowSpeed / deltaSlow;
			eigenvectorsInverseWrtPrimitives[5 + NUM_STATES * 4] = 0.f;
			eigenvectorsInverseWrtPrimitives[5 + NUM_STATES * 5] = slowSpeedSq * magneticField.y / deltaSlow;
			eigenvectorsInverseWrtPrimitives[5 + NUM_STATES * 6] = slowSpeedSq * magneticField.z / deltaSlow;
			eigenvectorsInverseWrtPrimitives[5 + NUM_STATES * 7] = 1.f / density;
			//Alfven row
			eigenvectorsInverseWrtPrimitives[6 + NUM_STATES * 0] = 0.f;
			eigenvectorsInverseWrtPrimitives[6 + NUM_STATES * 1] = 0.f;
			eigenvectorsInverseWrtPrimitives[6 + NUM_STATES * 2] = sgnBx * magneticField.z;
			eigenvectorsInverseWrtPrimitives[6 + NUM_STATES * 3] = sgnBx * -magneticField.y;
			eigenvectorsInverseWrtPrimitives[6 + NUM_STATES * 4] = 0.f;
			eigenvectorsInverseWrtPrimitives[6 + NUM_STATES * 5] = -magneticField.z / sqrtDensity;
			eigenvectorsInverseWrtPrimitives[6 + NUM_STATES * 6] = magneticField.y / sqrtDensity;
			eigenvectorsInverseWrtPrimitives[6 + NUM_STATES * 7] = 0.f;
			//fast magnetoacoustic row
			eigenvectorsInverseWrtPrimitives[7 + NUM_STATES * 0] = 0.f;
			eigenvectorsInverseWrtPrimitives[7 + NUM_STATES * 1] = fastSpeed;
			eigenvectorsInverseWrtPrimitives[7 + NUM_STATES * 2] = -magneticField.x * magneticField.y * fastSpeed / deltaFast;
			eigenvectorsInverseWrtPrimitives[7 + NUM_STATES * 3] = -magneticField.x * magneticField.z * fastSpeed / deltaFast;
			eigenvectorsInverseWrtPrimitives[7 + NUM_STATES * 4] = 0.f;
			eigenvectorsInverseWrtPrimitives[7 + NUM_STATES * 5] = fastSpeedSq * magneticField.y / deltaFast;
			eigenvectorsInverseWrtPrimitives[7 + NUM_STATES * 6] = fastSpeedSq * magneticField.z / deltaFast;
			eigenvectorsInverseWrtPrimitives[7 + NUM_STATES * 7] = 1.f / density;
		
			
		} else {
			
			real fastNormalization = deltaFast * M_SQRT_1_2 / (fastSpeed * sqrt(deltaFast * deltaFast + magneticFieldXSq * magneticFieldTSq));
			
			real slowNormalization = deltaSlow * M_SQRT_1_2 / (slowSpeed * sqrt(deltaSlow * deltaSlow + magneticFieldXSq * magneticFieldTSq));
			if (slowSpeed == 0.f) slowNormalization = 1.f;
		
			real alfvenNormalization = M_SQRT_1_2 / magneticFieldT;

			//fast magnetoacoustic col 
			eigenvectorsWrtPrimitives[0 + NUM_STATES * 0] = density * fastNormalization;
			eigenvectorsWrtPrimitives[1 + NUM_STATES * 0] = -fastSpeed * fastNormalization;
			eigenvectorsWrtPrimitives[2 + NUM_STATES * 0] = magneticField.x * magneticField.y * fastSpeed / deltaFast * fastNormalization;
			eigenvectorsWrtPrimitives[3 + NUM_STATES * 0] = magneticField.x * magneticField.z * fastSpeed / deltaFast * fastNormalization;
			eigenvectorsWrtPrimitives[4 + NUM_STATES * 0] = 0.f;
			eigenvectorsWrtPrimitives[5 + NUM_STATES * 0] = density * fastSpeedSq * magneticField.y / deltaFast * fastNormalization;
			eigenvectorsWrtPrimitives[6 + NUM_STATES * 0] = density * fastSpeedSq * magneticField.z / deltaFast * fastNormalization;
			eigenvectorsWrtPrimitives[7 + NUM_STATES * 0] = density * speedOfSoundSq * fastNormalization;
			//Alfven col
			eigenvectorsWrtPrimitives[0 + NUM_STATES * 1] = 0.f;
			eigenvectorsWrtPrimitives[1 + NUM_STATES * 1] = 0.f;
			eigenvectorsWrtPrimitives[2 + NUM_STATES * 1] = sgnBx * magneticField.z * alfvenNormalization;
			eigenvectorsWrtPrimitives[3 + NUM_STATES * 1] = sgnBx * -magneticField.y * alfvenNormalization;
			eigenvectorsWrtPrimitives[4 + NUM_STATES * 1] = 0.f;
			eigenvectorsWrtPrimitives[5 + NUM_STATES * 1] = magneticField.z * sqrtDensity * alfvenNormalization;
			eigenvectorsWrtPrimitives[6 + NUM_STATES * 1] = -magneticField.y * sqrtDensity * alfvenNormalization;
			eigenvectorsWrtPrimitives[7 + NUM_STATES * 1] = 0.f;
			//slow magnetoacoustic col
			eigenvectorsWrtPrimitives[0 + NUM_STATES * 2] = density * slowNormalization;
			eigenvectorsWrtPrimitives[1 + NUM_STATES * 2] = -slowSpeed * slowNormalization;
			eigenvectorsWrtPrimitives[2 + NUM_STATES * 2] = magneticField.x * magneticField.y * slowSpeed / deltaSlow * slowNormalization;
			eigenvectorsWrtPrimitives[3 + NUM_STATES * 2] = magneticField.x * magneticField.z * slowSpeed / deltaSlow * slowNormalization;
			eigenvectorsWrtPrimitives[4 + NUM_STATES * 2] = 0.f;
			eigenvectorsWrtPrimitives[5 + NUM_STATES * 2] = density * slowSpeedSq * magneticField.y / deltaSlow * slowNormalization;
			eigenvectorsWrtPrimitives[6 + NUM_STATES * 2] = density * slowSpeedSq * magneticField.z / deltaSlow * slowNormalization;
			eigenvectorsWrtPrimitives[7 + NUM_STATES * 2] = density * speedOfSoundSq * slowNormalization;
			//entropy col
			eigenvectorsWrtPrimitives[0 + NUM_STATES * 3] = 1.f;
			eigenvectorsWrtPrimitives[1 + NUM_STATES * 3] = 0.f; 
			eigenvectorsWrtPrimitives[2 + NUM_STATES * 3] = 0.f;
			eigenvectorsWrtPrimitives[3 + NUM_STATES * 3] = 0.f;
			eigenvectorsWrtPrimitives[4 + NUM_STATES * 3] = 0.f;
			eigenvectorsWrtPrimitives[5 + NUM_STATES * 3] = 0.f;
			eigenvectorsWrtPrimitives[6 + NUM_STATES * 3] = 0.f;
			eigenvectorsWrtPrimitives[7 + NUM_STATES * 3] = 0.f;	
			//divergence col 
			eigenvectorsWrtPrimitives[0 + NUM_STATES * 4] = 0.f;
			eigenvectorsWrtPrimitives[1 + NUM_STATES * 4] = 0.f;
			eigenvectorsWrtPrimitives[2 + NUM_STATES * 4] = 0.f;
			eigenvectorsWrtPrimitives[3 + NUM_STATES * 4] = 0.f;
			eigenvectorsWrtPrimitives[4 + NUM_STATES * 4] = 1.f;
			eigenvectorsWrtPrimitives[5 + NUM_STATES * 4] = 0.f;
			eigenvectorsWrtPrimitives[6 + NUM_STATES * 4] = 0.f;
			eigenvectorsWrtPrimitives[7 + NUM_STATES * 4] = 0.f;
			//slow magnetoacoustic col
			eigenvectorsWrtPrimitives[0 + NUM_STATES * 5] = density * slowNormalization;
			eigenvectorsWrtPrimitives[1 + NUM_STATES * 5] = slowSpeed * slowNormalization;
			eigenvectorsWrtPrimitives[2 + NUM_STATES * 5] = -magneticField.x * magneticField.y * slowSpeed / deltaSlow * slowNormalization;
			eigenvectorsWrtPrimitives[3 + NUM_STATES * 5] = -magneticField.x * magneticField.z * slowSpeed / deltaSlow * slowNormalization;
			eigenvectorsWrtPrimitives[4 + NUM_STATES * 5] = 0.f;
			eigenvectorsWrtPrimitives[5 + NUM_STATES * 5] = density * slowSpeedSq * magneticField.y / deltaSlow * slowNormalization;
			eigenvectorsWrtPrimitives[6 + NUM_STATES * 5] = density * slowSpeedSq * magneticField.z / deltaSlow * slowNormalization;
			eigenvectorsWrtPrimitives[7 + NUM_STATES * 5] = density * speedOfSoundSq * slowNormalization;
			//Alfven col
			eigenvectorsWrtPrimitives[0 + NUM_STATES * 6] = 0.f;
			eigenvectorsWrtPrimitives[1 + NUM_STATES * 6] = 0.f;
			eigenvectorsWrtPrimitives[2 + NUM_STATES * 6] = sgnBx * magneticField.z * alfvenNormalization;
			eigenvectorsWrtPrimitives[3 + NUM_STATES * 6] = sgnBx * -magneticField.y * alfvenNormalization;
			eigenvectorsWrtPrimitives[4 + NUM_STATES * 6] = 0.f;
			eigenvectorsWrtPrimitives[5 + NUM_STATES * 6] = -magneticField.z * sqrtDensity * alfvenNormalization;
			eigenvectorsWrtPrimitives[6 + NUM_STATES * 6] = magneticField.y * sqrtDensity * alfvenNormalization;
			eigenvectorsWrtPrimitives[7 + NUM_STATES * 6] = 0.f;
			//fast magnetoacoustic col
			eigenvectorsWrtPrimitives[0 + NUM_STATES * 7] = density * fastNormalization;
			eigenvectorsWrtPrimitives[1 + NUM_STATES * 7] = fastSpeed * fastNormalization;
			eigenvectorsWrtPrimitives[2 + NUM_STATES * 7] = -magneticField.x * magneticField.y * fastSpeed / deltaFast * fastNormalization;
			eigenvectorsWrtPrimitives[3 + NUM_STATES * 7] = -magneticField.x * magneticField.z * fastSpeed / deltaFast * fastNormalization;
			eigenvectorsWrtPrimitives[4 + NUM_STATES * 7] = 0.f;
			eigenvectorsWrtPrimitives[5 + NUM_STATES * 7] = density * fastSpeedSq * magneticField.y / deltaFast * fastNormalization;
			eigenvectorsWrtPrimitives[6 + NUM_STATES * 7] = density * fastSpeedSq * magneticField.z / deltaFast * fastNormalization;
			eigenvectorsWrtPrimitives[7 + NUM_STATES * 7] = density * speedOfSoundSq * fastNormalization;

			//fast magnetoacoustic row
			eigenvectorsInverseWrtPrimitives[0 + NUM_STATES * 0] = 0.f;
			eigenvectorsInverseWrtPrimitives[0 + NUM_STATES * 1] = -fastSpeed;
			eigenvectorsInverseWrtPrimitives[0 + NUM_STATES * 2] = magneticField.x * magneticField.y * fastSpeed / deltaFast;
			eigenvectorsInverseWrtPrimitives[0 + NUM_STATES * 3] = magneticField.x * magneticField.z * fastSpeed / deltaFast;
			eigenvectorsInverseWrtPrimitives[0 + NUM_STATES * 4] = 0.f;
			eigenvectorsInverseWrtPrimitives[0 + NUM_STATES * 5] = fastSpeedSq * magneticField.y / deltaFast;
			eigenvectorsInverseWrtPrimitives[0 + NUM_STATES * 6] = fastSpeedSq * magneticField.z / deltaFast;
			eigenvectorsInverseWrtPrimitives[0 + NUM_STATES * 7] = 1.f / density;
			//Alfven row
			eigenvectorsInverseWrtPrimitives[1 + NUM_STATES * 0] = 0.f;
			eigenvectorsInverseWrtPrimitives[1 + NUM_STATES * 1] = 0.f;
			eigenvectorsInverseWrtPrimitives[1 + NUM_STATES * 2] = sgnBx * magneticField.z;
			eigenvectorsInverseWrtPrimitives[1 + NUM_STATES * 3] = sgnBx * -magneticField.y;
			eigenvectorsInverseWrtPrimitives[1 + NUM_STATES * 4] = 0.f;
			eigenvectorsInverseWrtPrimitives[1 + NUM_STATES * 5] = magneticField.z / sqrtDensity;
			eigenvectorsInverseWrtPrimitives[1 + NUM_STATES * 6] = -magneticField.y / sqrtDensity;
			eigenvectorsInverseWrtPrimitives[1 + NUM_STATES * 7] = 0.f;
			//slow magnetoacoustic row
			eigenvectorsInverseWrtPrimitives[2 + NUM_STATES * 0] = 0.f;
			eigenvectorsInverseWrtPrimitives[2 + NUM_STATES * 1] = -slowSpeed;
			eigenvectorsInverseWrtPrimitives[2 + NUM_STATES * 2] = magneticField.x * magneticField.y * slowSpeed / deltaSlow;
			eigenvectorsInverseWrtPrimitives[2 + NUM_STATES * 3] = magneticField.x * magneticField.z * slowSpeed / deltaSlow;
			eigenvectorsInverseWrtPrimitives[2 + NUM_STATES * 4] = 0.f;
			eigenvectorsInverseWrtPrimitives[2 + NUM_STATES * 5] = slowSpeedSq * magneticField.y / deltaSlow;
			eigenvectorsInverseWrtPrimitives[2 + NUM_STATES * 6] = slowSpeedSq * magneticField.z / deltaSlow;
			eigenvectorsInverseWrtPrimitives[2 + NUM_STATES * 7] = 1.f / density;
			//entropy row
			eigenvectorsInverseWrtPrimitives[3 + NUM_STATES * 0] = 1.f;
			eigenvectorsInverseWrtPrimitives[3 + NUM_STATES * 1] = 0.f;
			eigenvectorsInverseWrtPrimitives[3 + NUM_STATES * 2] = 0.f;
			eigenvectorsInverseWrtPrimitives[3 + NUM_STATES * 3] = 0.f;
			eigenvectorsInverseWrtPrimitives[3 + NUM_STATES * 4] = 0.f;
			eigenvectorsInverseWrtPrimitives[3 + NUM_STATES * 5] = 0.f;
			eigenvectorsInverseWrtPrimitives[3 + NUM_STATES * 6] = 0.f;
			eigenvectorsInverseWrtPrimitives[3 + NUM_STATES * 7] = -1.f / speedOfSoundSq;
			//divergence row
			eigenvectorsInverseWrtPrimitives[4 + NUM_STATES * 0] = 0.f;
			eigenvectorsInverseWrtPrimitives[4 + NUM_STATES * 1] = 0.f;
			eigenvectorsInverseWrtPrimitives[4 + NUM_STATES * 2] = 0.f;
			eigenvectorsInverseWrtPrimitives[4 + NUM_STATES * 3] = 0.f;
			eigenvectorsInverseWrtPrimitives[4 + NUM_STATES * 4] = 1.f;
			eigenvectorsInverseWrtPrimitives[4 + NUM_STATES * 5] = 0.f;
			eigenvectorsInverseWrtPrimitives[4 + NUM_STATES * 6] = 0.f;
			eigenvectorsInverseWrtPrimitives[4 + NUM_STATES * 7] = 0.f;
			//slow magnetoacoustic row
			eigenvectorsInverseWrtPrimitives[5 + NUM_STATES * 0] = 0.f;
			eigenvectorsInverseWrtPrimitives[5 + NUM_STATES * 1] = slowSpeed;
			eigenvectorsInverseWrtPrimitives[5 + NUM_STATES * 2] = -magneticField.x * magneticField.y * slowSpeed / deltaSlow;
			eigenvectorsInverseWrtPrimitives[5 + NUM_STATES * 3] = -magneticField.x * magneticField.z * slowSpeed / deltaSlow;
			eigenvectorsInverseWrtPrimitives[5 + NUM_STATES * 4] = 0.f;
			eigenvectorsInverseWrtPrimitives[5 + NUM_STATES * 5] = slowSpeedSq * magneticField.y / deltaSlow;
			eigenvectorsInverseWrtPrimitives[5 + NUM_STATES * 6] = slowSpeedSq * magneticField.z / deltaSlow;
			eigenvectorsInverseWrtPrimitives[5 + NUM_STATES * 7] = 1.f / density;
			//Alfven row
			eigenvectorsInverseWrtPrimitives[6 + NUM_STATES * 0] = 0.f;
			eigenvectorsInverseWrtPrimitives[6 + NUM_STATES * 1] = 0.f;
			eigenvectorsInverseWrtPrimitives[6 + NUM_STATES * 2] = sgnBx * magneticField.z;
			eigenvectorsInverseWrtPrimitives[6 + NUM_STATES * 3] = sgnBx * -magneticField.y;
			eigenvectorsInverseWrtPrimitives[6 + NUM_STATES * 4] = 0.f;
			eigenvectorsInverseWrtPrimitives[6 + NUM_STATES * 5] = -magneticField.z / sqrtDensity;
			eigenvectorsInverseWrtPrimitives[6 + NUM_STATES * 6] = magneticField.y / sqrtDensity;
			eigenvectorsInverseWrtPrimitives[6 + NUM_STATES * 7] = 0.f;
			//fast magnetoacoustic row
			eigenvectorsInverseWrtPrimitives[7 + NUM_STATES * 0] = 0.f;
			eigenvectorsInverseWrtPrimitives[7 + NUM_STATES * 1] = fastSpeed;
			eigenvectorsInverseWrtPrimitives[7 + NUM_STATES * 2] = -magneticField.x * magneticField.y * fastSpeed / deltaFast;
			eigenvectorsInverseWrtPrimitives[7 + NUM_STATES * 3] = -magneticField.x * magneticField.z * fastSpeed / deltaFast;
			eigenvectorsInverseWrtPrimitives[7 + NUM_STATES * 4] = 0.f;
			eigenvectorsInverseWrtPrimitives[7 + NUM_STATES * 5] = fastSpeedSq * magneticField.y / deltaFast;
			eigenvectorsInverseWrtPrimitives[7 + NUM_STATES * 6] = fastSpeedSq * magneticField.z / deltaFast;
			eigenvectorsInverseWrtPrimitives[7 + NUM_STATES * 7] = 1.f / density;
		}
	}

#if 1
	if (index == DEBUG_INDEX) {
		printf("side %d\n", side);
		printf("i %d\n", index);
		//heart of current problem: magnetic energy density is exceeding our total energy density
		// so the K+P energy density comes out negative ...
		//magnetic energy density comes from the magnetic field states
		//total energy density comes from the the ENERGY_TOTAL state
		// this means our eigenvectors are contributing less to total energy than they should be. 
		printf("totalPlasmaEnergyDensityL %f\n", totalPlasmaEnergyDensityL);
		printf("magneticEnergyDensityL %f\n", magneticEnergyDensityL);
		printf("potentialEnergyDensityL %f\n", potentialEnergyDensityL);
		printf("kineticEnergyDensityL %f\n", kineticEnergyDensityL);
		printf("totalHydroEnergyDensityL %f\n", totalHydroEnergyDensityL);	//shouldn't be negative
		printf("internalEnergyDensityL %f\n", internalEnergyDensityL);
		printf("density %f\n", density);
		printf("gamma %f\n", gamma);
		printf("pressureL %f\n", pressureL);
		printf("pressureR %f\n", pressureR);
		printf("pressure %f\n", pressure);
		printf("speedOfSound %f\n", speedOfSound);
		printf("deltaSlow %f\n", deltaSlow);
		printf("slowSpeed %f\n", slowSpeed);
		printf("magnetic field %f %f %f\n", magneticField.x, magneticField.y, magneticField.z);
		printf("slow normalization discriminant %f\n", deltaSlow * deltaSlow + magneticFieldXSq * magneticFieldTSq);
		printf("eigenvalues");
		for (int i = 0; i < NUM_STATES; ++i) {
			printf(" %f", eigenvalues[i]);
		}
		printf("\n");
		printf("primitive eigenvectors\n");
		for (int i = 0; i < NUM_STATES; ++i) {
			for (int j = 0; j < NUM_STATES; ++j) {
				printf(" %f", eigenvectorsWrtPrimitives[i + NUM_STATES * j]);
			}
			printf("\n");
		}
		printf("primitive eigenvector inverse\n");
		for (int i = 0; i < NUM_STATES; ++i) {
			for (int j = 0; j < NUM_STATES; ++j) {
				printf(" %f", eigenvectorsInverseWrtPrimitives[i + NUM_STATES * j]);
			}
			printf("\n");
		}	
		printf("primitive eigenbasis orthogonality\n");
		real totalError = 0.f;
		for (int i = 0; i < NUM_STATES; ++i) {
			for (int j = 0; j < NUM_STATES; ++j) {
				real sum = 0.f;
				for (int k = 0; k < NUM_STATES; ++k) {
					sum += eigenvectorsInverseWrtPrimitives[i + NUM_STATES * k] * eigenvectorsWrtPrimitives[k + NUM_STATES * j];
				}
				printf(" %f", sum);
				totalError += fabs(sum - (i == j ? 1.f : 0.f));
			}
			printf("\n");
		}
		printf("eigenbasis error %f\n", totalError);
	}
#endif

	//left and right eigenvectors above are of the flux derivative with respect to primitive variables
	//to find the eigenvectors of the flux with respect to the state variables, multiply by the derivative of the primitives with respect to the states
	//L = l * dw/du, R = du/dw * r
	//for l, r the left and right eigenvectors of derivative of flux wrt primitives
	//u = states, w = primitives
	//L, R the left and right eigenvectors of derivative of flux wrt state
	//this matches up with A = Q V Q^-1 = R V L = du/dw r V l dw/du

	real8 du_dw8[8];	//row-major
	du_dw8[0] = (real8)(1.f, 0.f, 0.f, 0.f, 0.f, 0.f, 0.f, 0.f);
	du_dw8[1] = (real8)(velocity.x, density, 0.f, 0.f, 0.f, 0.f, 0.f, 0.f);
	du_dw8[2] = (real8)(velocity.y, 0.f, density, 0.f, 0.f, 0.f, 0.f, 0.f);
	du_dw8[3] = (real8)(velocity.z, 0.f, 0.f, density, 0.f, 0.f, 0.f, 0.f);
	du_dw8[4] = (real8)(0.f, 0.f, 0.f, 0.f, 1.f, 0.f, 0.f, 0.f);
	du_dw8[5] = (real8)(0.f, 0.f, 0.f, 0.f, 0.f, 1.f, 0.f, 0.f);
	du_dw8[6] = (real8)(0.f, 0.f, 0.f, 0.f, 0.f, 0.f, 1.f, 0.f);
	du_dw8[7] = (real8)(.5f * velocitySq, density * velocity.x, density * velocity.y, density * velocity.z, magneticField.x, magneticField.y, magneticField.z, 1.f / gammaMinusOne);
	real* du_dw = (real*)du_dw8;

	real8 dw_du8[8];	//row-major
	dw_du8[0] = (real8)(1.f, 0.f, 0.f, 0.f, 0.f, 0.f, 0.f, 0.f);
	dw_du8[1] = (real8)(-velocity.x / density, 1.f / density, 0.f, 0.f, 0.f, 0.f, 0.f, 0.f);
	dw_du8[2] = (real8)(-velocity.y / density, 0.f, 1.f / density, 0.f, 0.f, 0.f, 0.f, 0.f);
	dw_du8[3] = (real8)(-velocity.z / density, 0.f, 0.f, 1.f / density, 0.f, 0.f, 0.f, 0.f);
	dw_du8[4] = (real8)(0.f, 0.f, 0.f, 0.f, 1.f, 0.f, 0.f, 0.f);
	dw_du8[5] = (real8)(0.f, 0.f, 0.f, 0.f, 0.f, 1.f, 0.f, 0.f);
	dw_du8[6] = (real8)(0.f, 0.f, 0.f, 0.f, 0.f, 0.f, 1.f, 0.f);
	dw_du8[7] = (real8)(.5f * gammaMinusOne * velocitySq, -gammaMinusOne * velocity.x, -gammaMinusOne * velocity.y, -gammaMinusOne * velocity.z, -gammaMinusOne * magneticField.x, -gammaMinusOne * magneticField.y, -gammaMinusOne * magneticField.z, gammaMinusOne);
	real* dw_du = (real*)dw_du8;

	//L = l * dw/du <=> L_j = l_k * [dw/du]_kj <=> L_ij = l_ik * [dw/du]_kj
	//R = du/dw * r <=> R_i = [du/dw]_ik * r_k <=> R_ij = [du/dw]_ik * r_kj
	for (int i = 0; i < NUM_STATES; ++i) {
		for (int j = 0; j < NUM_STATES; ++j) {
			real sum;
			
			sum = 0.f;
			for (int k = 0; k < NUM_STATES; ++k) {
				sum += eigenvectorsInverseWrtPrimitives[i + NUM_STATES * k] * dw_du[k + NUM_STATES * j];
			}
			eigenvectorsInverse[i + NUM_STATES * j] = sum;
			
			sum = 0.f;
			for (int k = 0; k < NUM_STATES; ++k) {
				sum += du_dw[i + NUM_STATES * k] * eigenvectorsWrtPrimitives[k + NUM_STATES * j];
			}
			eigenvectors[i + NUM_STATES * j] = sum;
		}
	}

#if 1
	if (index == DEBUG_INDEX) {
		printf("side %d\n", side);
		printf("i %d\n", index);
		printf("conservative eigenbasis orthogonality\n");
		real totalError = 0.f;
		for (int i = 0; i < NUM_STATES; ++i) {
			for (int j = 0; j < NUM_STATES; ++j) {
				real sum = 0.f;
				for (int k = 0; k < NUM_STATES; ++k) {
					sum += eigenvectorsInverse[i + NUM_STATES * k] * eigenvectors[k + NUM_STATES * j];
				}
				printf(" %f", sum);
				totalError += fabs(sum - (i == j ? 1.f : 0.f));
			}
			printf("\n");
		}
		printf("eigenbasis error %f\n", totalError);
	}
#endif

#if DIM > 1
	if (side == 1) {
		for (int i = 0; i < NUM_STATES; ++i) {
			real tmp;

			//-90' rotation applied to the LHS of incoming velocity vectors, to move their y axis into the x axis
			// is equivalent of a -90' rotation applied to the RHS of the flux jacobian A
			// and A = Q V Q-1 for Q = the right eigenvectors and Q-1 the left eigenvectors
			// so a -90' rotation applied to the RHS of A is a +90' rotation applied to the RHS of Q-1 the left eigenvectors
			//and while a rotation applied to the LHS of a vector rotates the elements of its column vectors, a rotation applied to the RHS rotates the elements of its row vectors 
			//each row's y <- x, x <- -y
			tmp = eigenvectorsInverse[i + NUM_STATES * STATE_MOMENTUM_X];
			eigenvectorsInverse[i + NUM_STATES * STATE_MOMENTUM_X] = -eigenvectorsInverse[i + NUM_STATES * STATE_MOMENTUM_Y];
			eigenvectorsInverse[i + NUM_STATES * STATE_MOMENTUM_Y] = tmp;
			
			tmp = eigenvectorsInverse[i + NUM_STATES * STATE_MAGNETIC_FIELD_X];
			eigenvectorsInverse[i + NUM_STATES * STATE_MAGNETIC_FIELD_X] = -eigenvectorsInverse[i + NUM_STATES * STATE_MAGNETIC_FIELD_Y];
			eigenvectorsInverse[i + NUM_STATES * STATE_MAGNETIC_FIELD_Y] = tmp;
			
			//a -90' rotation applied to the RHS of A must be corrected with a 90' rotation on the LHS of A
			//this rotates the elements of the column vectors by 90'
			//each column's x <- y, y <- -x
			tmp = eigenvectors[STATE_MOMENTUM_X + NUM_STATES * i];
			eigenvectors[STATE_MOMENTUM_X + NUM_STATES * i] = -eigenvectors[STATE_MOMENTUM_Y + NUM_STATES * i];
			eigenvectors[STATE_MOMENTUM_Y + NUM_STATES * i] = tmp;
			
			tmp = eigenvectors[STATE_MAGNETIC_FIELD_X + NUM_STATES * i];
			eigenvectors[STATE_MAGNETIC_FIELD_X + NUM_STATES * i] = -eigenvectors[STATE_MAGNETIC_FIELD_Y + NUM_STATES * i];
			eigenvectors[STATE_MAGNETIC_FIELD_Y + NUM_STATES * i] = tmp;
		}
	}
#if DIM > 2
	else if (side == 2) {
		for (int i = 0; i < NUM_STATES; ++i) {
			real tmp;
			
			tmp = eigenvectorsInverse[i + NUM_STATES * STATE_MOMENTUM_X];
			eigenvectorsInverse[i + NUM_STATES * STATE_MOMENTUM_X] = -eigenvectorsInverse[i + NUM_STATES * STATE_MOMENTUM_Z];
			eigenvectorsInverse[i + NUM_STATES * STATE_MOMENTUM_Z] = tmp;
			
			tmp = eigenvectorsInverse[i + NUM_STATES * STATE_MAGNETIC_FIELD_X];
			eigenvectorsInverse[i + NUM_STATES * STATE_MAGNETIC_FIELD_X] = -eigenvectorsInverse[i + NUM_STATES * STATE_MAGNETIC_FIELD_Z];
			eigenvectorsInverse[i + NUM_STATES * STATE_MAGNETIC_FIELD_Z] = tmp;
			
			tmp = eigenvectors[STATE_MOMENTUM_X + NUM_STATES * i];
			eigenvectors[STATE_MOMENTUM_X + NUM_STATES * i] = -eigenvectors[STATE_MOMENTUM_Z + NUM_STATES * i];
			eigenvectors[STATE_MOMENTUM_Z + NUM_STATES * i] = tmp;
			
			tmp = eigenvectors[STATE_MAGNETIC_FIELD_X + NUM_STATES * i];
			eigenvectors[STATE_MAGNETIC_FIELD_X + NUM_STATES * i] = -eigenvectors[STATE_MAGNETIC_FIELD_Z + NUM_STATES * i];
			eigenvectors[STATE_MAGNETIC_FIELD_Z + NUM_STATES * i] = tmp;
		}
	}
#endif
#endif
	

}

__kernel void calcEigenBasis(
	__global real* eigenvaluesBuffer,
	__global real* eigenvectorsBuffer,
	__global real* eigenvectorsInverseBuffer,
	const __global real* stateBuffer,
	const __global real* potentialBuffer)
{
	int4 i = (int4)(get_global_id(0), get_global_id(1), get_global_id(2), 0);
	if (i.x < 2 || i.x >= SIZE_X - 1 
#if DIM > 1
		|| i.y < 2 || i.y >= SIZE_Y - 1
#endif
#if DIM > 2
		|| i.z < 2 || i.z >= SIZE_Z - 1
#endif
	) return;

	calcEigenBasisSide(eigenvaluesBuffer, eigenvectorsBuffer, eigenvectorsInverseBuffer, stateBuffer, potentialBuffer, 0);
#if DIM > 1
	calcEigenBasisSide(eigenvaluesBuffer, eigenvectorsBuffer, eigenvectorsInverseBuffer, stateBuffer, potentialBuffer, 1);
#endif
#if DIM > 2
	calcEigenBasisSide(eigenvaluesBuffer, eigenvectorsBuffer, eigenvectorsInverseBuffer, stateBuffer, potentialBuffer, 2);
#endif
}

