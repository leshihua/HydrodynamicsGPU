#include "HydroGPU/HydroGPUApp.h"
#include "HydroGPU/RoeSolver.h"
#include "HydroGPU/BurgersSolver.h"
#include "Config/Config.h"
#include "Profiler/Profiler.h"
#include "Common/Exception.h"
#include "Common/File.h"
#include "Common/Macros.h"
#include <SDL2/SDL.h>
#include <OpenGL/gl.h>
#include <OpenGL/OpenGL.h>
#include <iostream>

//have to keep these updated with HydroGPU/Shared/Common.h

const char *displayMethodNames[NUM_DISPLAY_METHODS] = {
	"density",
	"velocity",
	"pressure",
	"gravity potential",
};

const char *boundaryMethodNames[NUM_BOUNDARY_METHODS] = {
	"periodic",
	"mirror",
	"freeflow",
};

HydroGPUApp::HydroGPUApp()
: Super()
, fluidTex(GLuint())
, gradientTex(GLuint())
, configFilename("config.lua")
, solverName("Burgers")
, doUpdate(1)
, maxFrames(-1)
, currentFrame(0)
, useFixedDT(false)
, fixedDT(.001f)
, cfl(.5f)
, displayMethod(DISPLAY_DENSITY)
, displayScale(2.f)
, boundaryMethod(BOUNDARY_PERIODIC)
, useGravity(true)
, noise(0)
, gamma(1.4)
, leftButtonDown(false)
, rightButtonDown(false)
, leftShiftDown(false)
, rightShiftDown(false)
, leftGuiDown(false)
, rightGuiDown(false)
, viewZoom(1.f)
{
	for (int i = 0; i < DIM; ++i) {
		size.s[i] = 512;
	}
}

int HydroGPUApp::main(std::vector<std::string> args) {
	for (int i = 1; i < args.size(); ++i) {
		if (i < args.size()-1 && args[i] == "-e") {
			configString = args[++i];
		} else {
			configFilename = args[++i];
		}
	}
	return Super::main(args);
}

void HydroGPUApp::init() {
	//config before Super::init so we can provide it 'useGPU'
	config = std::make_shared<Config::Config>();
	{	//I could either interpret strings for enum names, or I could provide tables of enum values..
		std::ostringstream s;
		s << "boundaryMethods = {\n";
		for (int i = 0; i < NUM_BOUNDARY_METHODS; ++i) {
			s << "\t['" << boundaryMethodNames[i] << "'] = " << i << ",\n";
		}
		s << "}\n";
		s << "displayMethods = {\n";
		for (int i = 0; i < NUM_DISPLAY_METHODS; ++i) {
			s << "\t['" << displayMethodNames[i] << "'] = " << i << ",\n";
		}
		s << "}\n";
		config->loadString(s.str());
	}
	std::cout << "loading config file " << configFilename << std::endl;
	config->loadFile(configFilename);
	if (!configString.empty()) {
		std::cout << "loading config string " << configString << std::endl;
		config->loadString(configString);
	}
	config->get("useGPU", useGPU);
	config->get("sizeX", size.s[0]);
	config->get("sizeY", size.s[1]);
	config->get("maxFrames", maxFrames);
	config->get("solverName", solverName);
	config->get("xmin", xmin.s[0]);
	config->get("ymin", xmin.s[1]);
	config->get("xmax", xmax.s[0]);
	config->get("ymax", xmax.s[1]);
	config->get("useFixedDT", useFixedDT);
	config->get("cfl", cfl);
	config->get("noise", noise);
	config->get("gamma", gamma);
	config->get("displayMethod", displayMethod);
	config->get("displayScale", displayScale);
	config->get("boundaryMethod", boundaryMethod);
	config->get("useGravity", useGravity);

	Super::init();


	int err;
	  
	for (int n = 0; n < DIM; ++n) {
		xmin.s[n] = -.5f;
		xmax.s[n] = .5f;
	}
	
	//get a texture going for visualizing the output
	glGenTextures(1, &fluidTex);
	glBindTexture(GL_TEXTURE_2D, fluidTex);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	glTexImage2D(GL_TEXTURE_2D, 0, 4, size.s[0], size.s[1], 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
	glBindTexture(GL_TEXTURE_2D, 0);
	if ((err = glGetError()) != 0) throw Common::Exception() << "failed to create GL texture.  got error " << err;

	//hmm, my cl.hpp version only supports clCreateFromGLTexture2D, which is deprecated ... do I use the deprecated method, or do I stick with the C structures?
	// ... or do I look for a more up-to-date version of cl.hpp
	fluidTexMem = cl::ImageGL(context, CL_MEM_WRITE_ONLY, GL_TEXTURE_2D, 0, fluidTex);

	//gradient texture
	{
		glGenTextures(1, &gradientTex);
		glBindTexture(GL_TEXTURE_2D, gradientTex);

		float colors[][3] = {
			{0, 0, 0},
			{0, 0, .5},
			{1, .5, 0},
			{1, 0, 0}
		};

		const int width = 256;
		unsigned char data[width*3];
		for (int i = 0; i < width; ++i) {
			float f = (float)i / (float)width * (float)numberof(colors);
			int ci = (int)f;
			int ci2 = (ci + 1) % numberof(colors);
			float s = f - (float)ci;
			if (ci >= numberof(colors)) {
				ci = numberof(colors)-1;
				s = 0;
			}

			for (int j = 0; j < 3; ++j) {
				data[3 * i + j] = (unsigned char)(255. * (colors[ci][j] * (1.f - s) + colors[ci2][j] * s));
			}
		}

		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, width, 1, 0, GL_RGB, GL_UNSIGNED_BYTE, data);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
		glBindTexture(GL_TEXTURE_2D, 0);
	}

	gradientTexMem = cl::ImageGL(context, CL_MEM_READ_ONLY, GL_TEXTURE_2D, 0, gradientTex);

	//read in the initial state
	std::vector<real4> stateVec(size.s[0] * size.s[1]);
	{
		int index[DIM];

		//ideal: config.get<real4(real2)>("initState", callback);
		//or even in the loop: *state = config.get("initState")(x,y)
		// then use template specialization to provide conversion to/from real2 and real4 ... be it nested in tables or not?
		std::function<real4(real2)> callback = [&](real2 x) -> real4 {
			//default callback
			bool inside = fabs(x.s[0]) < .15 && fabs(x.s[1]) < .15;
			//bool inside = x.s[0] < -.2 && x.s[1] < -.2;
			real density = inside ? 1. : .1;
			Tensor::Vector<real, 2> velocity;
			real specificKineticEnergy = 0.;
			for (int n = 0; n < DIM; ++n) {
				velocity(n) = crand() * noise;
				specificKineticEnergy += velocity(n) * velocity(n);
			}
			specificKineticEnergy *= .5;
			real specificInternalEnergy = 1.;
			real specificTotalEnergy = specificKineticEnergy + specificInternalEnergy;
		
			real4 state;
			state.s[0] = density;
			for (int n = 0; n < DIM; ++n) {
				state.s[n+1] = density * velocity(n);
			}
			state.s[DIM+1] = density * specificTotalEnergy;
			
			return state;
		};
		
		lua_State *L = config->getState();
		lua_getglobal(L, "initState");
		if (lua_isfunction(L, -1)) {
			callback = [&](real2 x) -> real4 {
				lua_getglobal(L, "initState");
				for (int i = 0; i < 2; ++i) {
					lua_pushnumber(L, x.s[i]);
				}
				config->call(2, 4);	//use our own error handler
				real4 result;
				for (int i = 0; i < 4; ++i) {
					result.s[i] = lua_tonumber(L, i-4);
				}
				lua_pop(L,4);
				return result;
			};
		}
		lua_pop(L, 1);

		std::cout << "initializing..." << std::endl;
		real4* state = &stateVec[0];	
		for (index[1] = 0; index[1] < size.s[1]; ++index[1]) {
			for (index[0] = 0; index[0] < size.s[0]; ++index[0], ++state) {
				real2 x;
				x.s[0] = real(xmax.s[0] - xmin.s[0]) * real(index[0]) / real(size.s[0]) + real(xmin.s[0]);
				x.s[1] = real(xmax.s[1] - xmin.s[1]) * real(index[1]) / real(size.s[1]) + real(xmin.s[1]);
				*state = callback(x);
			}
		}
		std::cout << "...done" << std::endl;
	}

	//construct the solver
	if (solverName == "Burgers") {
		solver = std::make_shared<BurgersSolver>(*this, stateVec);
	} else if (solverName == "Roe") {
		solver = std::make_shared<RoeSolver>(*this, stateVec);
	} else {
		throw Common::Exception() << "unknown solver " << solverName;
	}
	
	err = glGetError();
	if (err) throw Common::Exception() << "GL error " << err;

	std::cout << "Success!" << std::endl;
}

void HydroGPUApp::shutdown() {
	glDeleteTextures(1, &fluidTex);
	glDeleteTextures(1, &gradientTex);
}

void HydroGPUApp::resize(int width, int height) {
	Super::resize(width, height);	//viewport
	screenSize = Tensor::Vector<int,2>(width, height);
	aspectRatio = (float)width / (float)height;
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	glOrtho(-aspectRatio *.5, aspectRatio * .5, -.5, .5, -1., 1.);
	glMatrixMode(GL_MODELVIEW);
}

void HydroGPUApp::update() {
PROFILE_BEGIN_FRAME()

	++currentFrame;
	if (currentFrame == maxFrames) {
		doUpdate = 0;
	}

	Super::update();	//glclear 

	bool guiDown = leftGuiDown || rightGuiDown;
	if (rightButtonDown || (leftButtonDown && guiDown)) {
		solver->addDrop(mousePos, mouseVel);
	}
	
	//CPU need to bind beforehand for roe/cpu to use it
	//GPU needs it unbound until after the update
	if (!useGPU) {
		glBindTexture(GL_TEXTURE_2D, fluidTex);
	}
	
	if (doUpdate) {
		solver->update();
		if (doUpdate == 2) doUpdate = 0;
	}
	
	glPushMatrix();
	glTranslatef(-viewPos(0), -viewPos(1), 0);
	glScalef(viewZoom, viewZoom, viewZoom);
	glBindTexture(GL_TEXTURE_2D, fluidTex);
	glEnable(GL_TEXTURE_2D);
	glBegin(GL_QUADS);
	glTexCoord2f(0,0); glVertex2f(-.5f,-.5f);
	glTexCoord2f(1,0); glVertex2f(.5f,-.5f);
	glTexCoord2f(1,1); glVertex2f(.5f,.5f);
	glTexCoord2f(0,1); glVertex2f(-.5f,.5f);
	glEnd();
	glBindTexture(GL_TEXTURE_2D, 0);
	glPopMatrix();

	{int err = glGetError();
	if (err) std::cout << "GL error " << err << " at " << __LINE__ << std::endl;}
PROFILE_END_FRAME();
}

void HydroGPUApp::sdlEvent(SDL_Event &event) {
	bool shiftDown = leftShiftDown || rightShiftDown;
	bool guiDown = leftGuiDown || rightGuiDown;

	switch (event.type) {
	case SDL_MOUSEMOTION:
		{
			int dx = event.motion.xrel;
			int dy = event.motion.yrel;
			if (leftButtonDown && !guiDown) {
				if (shiftDown) {
					if (dy) {
						float scale = exp((float)dy * -.03f); 
						viewPos *= scale;
						viewZoom *= scale; 
					} 
				} else {
					if (dx || dy) {
						viewPos += Tensor::Vector<float,2>(-(float)dx * aspectRatio / (float)screenSize(0), (float)dy / (float)screenSize(1));
					}
				}
			}
		}
		{
			mousePos(0) = (float)event.motion.x / (float)screenSize(0) * (xmax.s[0] - xmin.s[0]) + xmin.s[0];
			mousePos(0) *= aspectRatio;	//only if xmin/xmax is symmetric. otehrwise more math required.
			mousePos(1) = (1.f - (float)event.motion.y / (float)screenSize(1)) * (xmax.s[1] - xmin.s[1]) + xmin.s[1];
			mousePos += viewPos;
			mousePos /= viewZoom;
			mouseVel(0) = (float)event.motion.xrel / (float)screenSize(0);
			mouseVel(1) = (float)event.motion.yrel / (float)screenSize(1);
		}
		break;
	case SDL_MOUSEBUTTONDOWN:
		if (event.button.button == SDL_BUTTON_LEFT) {
			leftButtonDown = true;
		}
		if (event.button.button == SDL_BUTTON_RIGHT) {
			rightButtonDown = true;
		}
		break;
	case SDL_MOUSEBUTTONUP:
		if (event.button.button == SDL_BUTTON_LEFT) {
			leftButtonDown = false;
		}
		if (event.button.button == SDL_BUTTON_RIGHT) {
			rightButtonDown = false;
		}
		break;
	case SDL_KEYDOWN:
		if (event.key.keysym.sym == SDLK_LSHIFT) {
			leftShiftDown = true;
		} else if (event.key.keysym.sym == SDLK_RSHIFT) {
			rightShiftDown = true;
		} else if (event.key.keysym.sym == SDLK_LGUI) {
			leftGuiDown = true;
		} else if (event.key.keysym.sym == SDLK_RGUI) {
			rightGuiDown = true;
		}
		break;
	case SDL_KEYUP:
		if (event.key.keysym.sym == SDLK_LSHIFT) {
			leftShiftDown = false;
		} else if (event.key.keysym.sym == SDLK_RSHIFT) {
			rightShiftDown = false;
		} else if (event.key.keysym.sym == SDLK_LGUI) {
			leftGuiDown = false;
		} else if (event.key.keysym.sym == SDLK_RGUI) {
			rightGuiDown = false;
		} else if (event.key.keysym.sym == SDLK_s) {
			if (shiftDown) {
				solver->save();
			} else {
				solver->screenshot();
			}
		} else if (event.key.keysym.sym == SDLK_f) {
			if (shiftDown) {
				displayScale *= .5;
			} else {
				displayScale *= 2.;
			}
			std::cout << "displayScale " << displayScale << std::endl;
		} else if (event.key.keysym.sym == SDLK_d) {
			if (shiftDown) {
				displayMethod = (displayMethod + NUM_DISPLAY_METHODS - 1) % NUM_DISPLAY_METHODS;
			} else {
				displayMethod = (displayMethod + 1) % NUM_DISPLAY_METHODS;
			}
			std::cout << "display " << displayMethodNames[displayMethod] << std::endl;
		} else if (event.key.keysym.sym == SDLK_b) {
			if (shiftDown) {
				boundaryMethod = (boundaryMethod + NUM_BOUNDARY_METHODS - 1) % NUM_BOUNDARY_METHODS;
			} else {
				boundaryMethod = (boundaryMethod + 1) % NUM_BOUNDARY_METHODS;
			}
			std::cout << "boundary " << boundaryMethodNames[boundaryMethod] << std::endl;
		} else if (event.key.keysym.sym == SDLK_u) {
			if (doUpdate) {
				doUpdate = 0;
			} else {
				if (shiftDown) {
					doUpdate = 2;
				} else {
					doUpdate = 1;
				}
			}
		}
		break;
	}
}

GLAPP_MAIN(HydroGPUApp)

