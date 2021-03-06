-- TODO add which equations work for this setup
-- some operate on multiple equations (particularly Euler, MHD, SRHD are all grouped together, and ADM1D, ADM3D, BSSNOK are all grouped together)

initConds = {
	
	-- Euler equation initial states

	--debugging
	{
		name='Constant',
		equations={'Euler', 'MHD', 'SRHD'},
		setup=function()
			initState = function(x,y,z)
				return buildStateEuler{
					x=x, y=y, z=z,
					density = 1,
					pressure = 1,
					velocityX = 1,
					velocityY = 1,
					velocityZ = 1,
					magneticFieldX = 1,
					magneticFieldY = 1,
					magneticFieldZ = 1,
				}
			end
		end,
	},
	
	{
		name='1D Advect Wave',
		equations={'Euler', 'MHD', 'SRHD'},
		setup=function()
			initState = function(x,y,z)
				local rSq = x * x + y * y + z * z
				return buildStateEuler{
					x=x, y=y, z=z,
					velocityX = 1,
					density = math.exp(-100*rSq) + 1,
					pressure = 1,
				}
			end
		end,
	},

	-- http://www.cfd-online.com/Wiki/Explosion_test_in_2-D
	{
		name='Sphere',
		equations={'Euler', 'MHD', 'SRHD'},
		setup=function()
			initState = function(x,y,z)
				local rSq = x * x + y * y + z * z
				local inside = rSq <= .2*.2
				return buildStateEuler{
					x=x, y=y, z=z,
					density = inside and 1 or .1,
					pressure = inside and 1 or .1,	--1 : .1 works for 2d but not 3d
				}
			end
		end,
	},

	{
		name='Sod',
		equations={'Euler', 'MHD', 'SRHD'},
		setup=function()
			--boundaryMethods = {{min='MIRROR', max='MIRROR'}, {min='MIRROR', max='MIRROR'}, {min='MIRROR', max='MIRROR'}}
			defs.idealGas_heatCapacityRatio = 7/5
			initState = function(x,y,z)
				local inside = x <= 0 and y <= 0 and z <= 0	
				return buildStateEuler{
					x=x, y=y, z=z,
					density = inside and 1 or .125,
					pressure = inside and 1 or .1,
				}
			end
		end,
	},


	-- 2D tests described in Alexander Kurganov, Eitan Tadmor, Solution of Two-Dimensional Riemann Problems for Gas Dynamics without Riemann Problem Solvers
	--  which says it is compared with  C. W. Schulz-Rinne, J. P. Collins, and H. M. Glaz, Numerical solution of the Riemann problem for two-dimensional gas dynamics
	-- and I can't find that paper right now

	{
		name='Configuration 1',
		equations={'Euler', 'MHD', 'SRHD'},
		setup=function()
			cfl = .475
			boundaryMethods = {{min='FREEFLOW', max='FREEFLOW'}, {min='FREEFLOW', max='FREEFLOW'}, {min='FREEFLOW', max='FREEFLOW'}}
			initState = function(x,y,z)
				return buildStateEulerQuadrant(x,y,z,{
					q1 = {density=1, pressure=1, velocityX=0, velocityY=0},
					q2 = {density=.5197, pressure=.4, velocityX=-.7259, velocityY=0},
					q3 = {density=.1072, pressure=.0439, velocityX=-.7259, velocityY=-1.4045},
					q4 = {density=.2579, pressure=.15, velocityX=0, velocityY=-1.4045},
				})
			end
		end,
	},
	
	{
		name='Configuration 2',
		equations={'Euler', 'MHD', 'SRHD'},
		setup=function()
			cfl = .475
			boundaryMethods = {{min='FREEFLOW', max='FREEFLOW'}, {min='FREEFLOW', max='FREEFLOW'}, {min='FREEFLOW', max='FREEFLOW'}}
			initState = function(x,y,z)
				return buildStateEulerQuadrant(x,y,z,{
					q1 = {density=1, pressure=1, velocityX=0, velocityY=0},
					q2 = {density=.5197, pressure=.4, velocityX=-.7259, velocityY=0},
					q3 = {density=1, pressure=1, velocityX=-.7259, velocityY=-.7259},
					q4 = {density=.5197, pressure=.4, velocityX=0, velocityY=-.7259},
				})
			end
		end,
	},

	-- HLL looks good
	-- Roe gets noise along -x axis, shows antisymmetry between axii, then blows up near the noise
	--   only when using the arbitrary-normal method.  when rotating into the x-axis it works fine
	{
		name='Configuration 3',
		equations={'Euler', 'MHD', 'SRHD'},
		setup=function()
			cfl = .475
			boundaryMethods = {{min='FREEFLOW', max='FREEFLOW'}, {min='FREEFLOW', max='FREEFLOW'}, {min='FREEFLOW', max='FREEFLOW'}}
			initState = function(x,y,z)
				return buildStateEulerQuadrant(x,y,z,{
					q1 = {density=1.5, pressure=1.5, velocityX=0, velocityY=0},
					q2 = {density=.5323, pressure=.3, velocityX=1.206, velocityY=0},
					q3 = {density=.138, pressure=.029, velocityX=1.206, velocityY=1.206},
					q4 = {density=.5323, pressure=.3, velocityX=0, velocityY=1.206},
				})
			end
		end,
	},

	{
		name='Configuration 4',
		equations={'Euler', 'MHD', 'SRHD'},
		setup=function()
			cfl = .475
			boundaryMethods = {{min='FREEFLOW', max='FREEFLOW'}, {min='FREEFLOW', max='FREEFLOW'}, {min='FREEFLOW', max='FREEFLOW'}}
			initState = function(x,y,z)
				return buildStateEulerQuadrant(x,y,z,{
					q1 = {density=1.1, pressure=1.1, velocityX=0, velocityY=0},
					q2 = {density=.5065, pressure=.35, velocityX=.8939, velocityY=0},
					q3 = {density=1.1, pressure=1.1, velocityX=.8939, velocityY=.8939},
					q4 = {density=.5065, pressure=.35, velocityX=0, velocityY=.8939},
				})
			end
		end,
	},

	{
		name='Configuration 5',
		equations={'Euler', 'MHD', 'SRHD'},
		setup=function()
			cfl = .475
			boundaryMethods = {{min='FREEFLOW', max='FREEFLOW'}, {min='FREEFLOW', max='FREEFLOW'}, {min='FREEFLOW', max='FREEFLOW'}}
			initState = function(x,y,z)
				return buildStateEulerQuadrant(x,y,z,{
					q1 = {density=1, pressure=1, velocityX=-.75, velocityY=-.5},
					q2 = {density=2, pressure=1, velocityX=-.75, velocityY=.5},
					q3 = {density=1, pressure=1, velocityX=.75, velocityY=.5},
					q4 = {density=3, pressure=1, velocityX=.75, velocityY=-.5},
				})
			end
		end,
	},

	{
		name='Configuration 6',
		equations={'Euler', 'MHD', 'SRHD'},
		setup=function()
			cfl = .475
			boundaryMethods = {{min='FREEFLOW', max='FREEFLOW'}, {min='FREEFLOW', max='FREEFLOW'}, {min='FREEFLOW', max='FREEFLOW'}}
			initState = function(x,y,z)
				return buildStateEulerQuadrant(x,y,z,{
					q1 = {density=1, pressure=1, velocityX=.75, velocityY=-.5},
					q2 = {density=2, pressure=1, velocityX=.75, velocityY=.5},
					q3 = {density=1, pressure=1, velocityX=-.75, velocityY=.5},
					q4 = {density=3, pressure=1, velocityX=-.75, velocityY=-.5},
				})
			end
		end,
	},

	-- looks good for HLL
	-- Roe not so much: wave moves faster when aligned with axii
	{
		name='Sedov',
		equations={'Euler', 'MHD', 'SRHD'},
		setup=function()
			local xmid = {
				(xmax[1] + xmin[1]) * .5,
				(xmax[2] + xmin[2]) * .5,
				(xmax[3] + xmin[3]) * .5,
			}
			local dx = {
				(xmax[1] - xmin[1]) / size[1],
				(xmax[2] - xmin[2]) / (size[2] or 1),
				(xmax[3] - xmin[3]) / (size[3] or 1),
			}
			initState = function(x,y,z)
				local x = x - xmid[1]
				local y = y - xmid[2]
				local z = z - xmid[3]
				if math.abs(x) < 1.5 * dx[1]
				and math.abs(y) < 1.5 * dx[2]
				and math.abs(z) < 1.5 * dx[3]
				then
					return buildStateEuler{
						x=x, y=y, z=z,
						density = 1,
						pressure = 1e+5,
					}
				else
					return buildStateEuler{
						x=x, y=y, z=z,
						density = 1,
						pressure = 1e-5,
					}
				end
			end
		end,
	},

	-- http://www.astro.uni-bonn.de/~jmackey/jmac/node7.html
	-- http://www.astro.princeton.edu/~jstone/Athena/tests/brio-wu/Brio-Wu.html
	{
		name='Brio-Wu',
		equations={'Euler', 'MHD', 'SRHD'},
		setup=function()
			defs.idealGas_heatCapacityRatio = 2
			initState = function(x,y,z)
				local lhs = x <= 0 and y <= 0 and z <= 0
				return buildStateEuler{
					x=x, y=y, z=z,
					density = lhs and 1 or .125,
					pressure = lhs and 1 or .1,
					magneticFieldX = .75,
					magneticFieldY = lhs and 1 or -1,
					magneticFieldZ = 0,
				}
			end
		end,
	},

	-- http://www.astro.virginia.edu/VITA/ATHENA/ot.html
	-- http://www.astro.princeton.edu/~jstone/Athena/tests/orszag-tang/pagesource.html
	{
		name='Orszag-Tang',
		equations={'Euler', 'MHD', 'SRHD'},
		setup=function()
			defs.idealGas_heatCapacityRatio = 5/3
			local B0 = 1/math.sqrt(4 * math.pi)
			-- assumes coordinate space to be [-.5,.5]^2
			initState = function(x,y,z)
				return buildStateEuler{
					x=x, y=y, z=z,
					density = 25/(36*math.pi),
					velocityX = -math.sin(2*math.pi*(y+.5)),
					velocityY = math.sin(2*math.pi*(x+.5)),
					velocityZ = 0,
					pressure = 5/(12*math.pi),	-- is this hydro pressure or total pressure?
					magneticFieldX = -B0 * math.sin(2 * math.pi * (y+.5)),
					magneticFieldY = B0 * math.sin(4 * math.pi * (x+.5)),
					magneticFieldZ = 0,
				}
			end
		end,
	},

	-- Colella-Woodward interacting blast wave problem
	{
		name='Colella-Woodward',
		equations={'Euler', 'MHD', 'SRHD'},
		setup=function()
			boundaryMethods = {{min='FREEFLOW', max='FREEFLOW'}, {min='FREEFLOW', max='FREEFLOW'}, {min='FREEFLOW', max='FREEFLOW'}}
			initState = function(x,y,z)
				local pressure
				if x < -.4 then
					pressure = 1000
				elseif x < .4 then
					pressure = .01
				else
					pressure = 100
				end
				return buildStateEuler{
					x=x, y=y, z=z,
					density = 1,
					velocityX = 0, velocityY = 0, velocityZ = 0,
					pressure = pressure,
				}
			end
		end,
	},

	--EulerBurgers is having trouble
	--EulerHLL works fine
	--EulerRoe at high resolutions after a long time shows some waves and then blows up
	{
		name='Kelvin-Helmholtz',
		equations={'Euler', 'MHD', 'SRHD'},
		setup=function()
			boundaryMethods = {{min='PERIODIC', max='PERIODIC'}, {min='PERIODIC', max='PERIODIC'}, {min='PERIODIC', max='PERIODIC'}}
			initState = function(x,y,z)
				local dim = #size
				local inside = y > -.25 and y < .25
				local theta = (x - xmin[1]) / (xmax[1] - xmin[1]) * 2 * math.pi
				if dim >= 3 then 
					theta = theta * (z - xmin[3]) / (xmax[3] - xmin[3]) 
				end
				local noise = size[1] * 2e-5
				return buildStateEuler{
					x=x, y=y, z=z,
					density = inside and 2 or 1,
					velocityX = math.cos(theta) * noise + (inside and -.5 or .5),
					velocityY = math.sin(theta) * noise,
					velocityZ = math.sin(theta) * noise,
					pressure = 2.5,
				}
			end
		end,
	},

	-- TODO pick one of these two ...
	-- http://www.astro.virginia.edu/VITA/ATHENA/dmr.html
	{
		name='Double Mach Reflection',
		equations={'Euler', 'MHD', 'SRHD'},
		setup=function()
			xmin[1] = 0
			xmax[1] = 4
			xmin[2] = 0
			xmax[2] = 1
			boundaryMethods[1] = {min='FREEFLOW', max='FREEFLOW'}
			boundaryMethods[2] = {min='MIRROR', max='MIRROR'}
			local x0 = 1/6
			initState = function(x,y,z)
				local lhs = x < x0 + y * (1/3)^(1/2)
				return buildStateEuler{
					x=x, y=y, z=z,
					density = lhs and 8 or 1.4,
					velocityX = lhs and 8.25 * math.cos(math.rad(30)) or 0,
					velocityY = lhs and -8.25 * math.cos(math.rad(30)) or 0,
					pressure = lhs and 116.5 or 1,
				}
			end
		end,
	},

	--http://www.astro.virginia.edu/VITA/ATHENA/dmr.html
	{
		name='Double Mach Reflection',
		equations={'Euler', 'MHD', 'SRHD'},
		setup=function()
			-- I am not correctly modeling the top boundary
			boundaryMethods = {
				{min='FREEFLOW', max='FREEFLOW'},
				{min='MIRROR', max='FREEFLOW'},
				{min='MIRROR', max='MIRROR'},
			}
			xmin = {0,0,0}
			xmax = {4,1,1}
			size[1] = size[1] * 2
			size[2] = size[2] / 2
			defs.idealGas_heatCapacityRatio = 1.4
			local sqrt1_3 = math.sqrt(1/3)
			initState = function(x,y,z)
				local inside = x < y * sqrt1_3
				if inside then
					return buildStateEuler{
						x=x, y=y, z=z,
						density = 8,
						pressure = 116.5,
						velocityX = 8.25 * math.cos(math.rad(30)),
						velocityY = -8.25 * math.sin(math.rad(30)),
					}
				else
					return buildStateEuler{
						x=x, y=y, z=z,
						density = 1.4,
						pressure = 1,
					}
				end
			end
		end,
	},
	
	-- http://www.cfd-online.com/Wiki/2-D_laminar/turbulent_driven_square_cavity_flow
	{
		name='Square Cavity',
		equations={'Euler', 'MHD', 'SRHD'},
		setup=function()
			boundaryMethods = {
				{min='MIRROR', max='MIRROR'},
				{min='MIRROR', max='NONE'},
				{min='MIRROR', max='MIRROR'},
			}
			initState = function(x,y,z)
				return buildStateEuler{
					x=x, y=y, z=z,
					density = 1,
					velocityX = y > .45 and 1 or 0,
					pressure = 1,
				}
			end
		end,
	},

	{
		name='Shock Bubble Interaction',
		equations={'Euler', 'MHD', 'SRHD'},
		setup=function()
			boundaryMethods = {
				{min='FREEFLOW', max='FREEFLOW'},
				{min='FREEFLOW', max='FREEFLOW'},
				{min='FREEFLOW', max='FREEFLOW'},
			}
			local bubbleX = 0
			local bubbleY = 0
			local bubbleZ = 0
			local bubbleRadius = .2
			local waveX = -.45
			xmin = {-1,-.5,-.5}
			xmax = {1,.5,.5}
			size[1] = size[1] * 2
			initState = function(x,y,z)
				local bubbleRSq = (x-bubbleX)^2 + (y-bubbleY)^2 + (z-bubbleZ)^2
				return buildStateEuler{
					x=x, y=y, z=z,
					density = (x < waveX) and 1 or (bubbleRSq < bubbleRadius*bubbleRadius and .1 or 1),
					pressure = (x < waveX) and 1 or .1,
					velocityX = (x < waveX) and 0 or -.5,
				}
			end
		end,
	},

	{
		name='Flow Around Cylinder',
		equations={'Euler', 'MHD', 'SRHD'},
		setup=function()
			boundaryMethods = {
				{min='NONE', max='FREEFLOW'},
				{min='FREEFLOW', max='FREEFLOW'},
				{min='FREEFLOW', max='FREEFLOW'},
			}
			local cylinderRadius = .25
			local cylinderRadiusSq = cylinderRadius * cylinderRadius 
			initState = function(x,y,z)
				local r2 = x*x + y*y + z*z
				return buildStateEuler{
					x=x, y=y, z=z,
					density = 1,
					velocityX = .2,
					pressure = 1,
					solid = r2 < cylinderRadiusSq and 1 or 0
				}
			end
		end,
	},

	-- solid flag is not reflecting atm ... hmm ...
	-- http://amroc.sourceforge.net/examples/euler/2d/html/ffstep_n.htm
	{
		name='Forward Facing Step',
		equations={'Euler', 'MHD', 'SRHD'},
		setup=function()
			boundaryMethods = {
				{min='FREEFLOW', max='FREEFLOW'},
				{min='MIRROR', max='MIRROR'},
				{min='MIRROR', max='MIRROR'},
			}
			--[[
			cfl = .95
			xmin = {0,0,0}
			xmax = {3,1,1}
			--]]
			xmid = {}
			for i=1,3 do xmid[i] = .5 * (xmin[i] + xmax[i]) end
			initState = function(x,y,z)
				local inside = x > xmid[1] and y < xmid[2]
				return buildStateEuler{
					x=x, y=y, z=z,
					density = 1.4,
					
					-- 'inside' shouldn't matter, because 'solid' should things
					-- ...but if these values are bad even for solid cells, the sim explodes
					velocityX = 3,
					pressure = 1,
					
					solid = inside and 1 or 0
				}
			end
		end,
	},

	{
		name='Spiral Implosion',
		equations={'Euler', 'MHD', 'SRHD'},
		setup=function()
			boundaryMethods = {
				{min='MIRROR', max='MIRROR'},
				{min='MIRROR', max='MIRROR'},
				{min='MIRROR', max='MIRROR'},
			}
			initState = function(x,y,z)
				local r = math.sqrt(x*x + y*y + z*z)
				local s = r > .25 and -1 or 1
				useGravity = true
				return buildStateEuler{
					x=x,y=y,z=z,
					density = 1.1 - math.exp(-x*x-y*y),
					velocityX = -y * s,
					velocityY = x * s,
					specificEnergyInternal = 1,
				}
			end
		end,
	},

	-- http://www.astro.princeton.edu/~jstone/Athena/tests/rt/rt.html
	{
		name='Rayleigh-Taylor',
		equations={'Euler', 'MHD', 'SRHD'},
		setup=function()
			local k = #size

			local xmid = {}
			for i=1,3 do xmid[i] = .5 * (xmin[i] + xmax[i]) end
			
			-- triple the length along the interface dimension
			xmin[k] = xmid[k] + (xmin[k] - xmid[k]) * 3
			xmax[k] = xmid[k] + (xmax[k] - xmid[k]) * 3

			-- triple resolution along interface dimension
			size[k] = size[k] * 3
			-- (can it handle npo2 sizes?)
			
			boundaryMethods = {
				{min='PERIODIC', max='PERIODIC'},
				{min='PERIODIC', max='PERIODIC'},
				{min='PERIODIC', max='PERIODIC'},
			}
			boundaryMethods[k] = {min='MIRROR', max='MIRROR'}
		
			-- TODO incorporate this into the Euler model ..
			local externalForce = {0, 1, 0}
			
			initState = function(x,y,z)
				local xs = {x,y,z}
				local top = xs[k] > xmid[k]
				local potentialEnergy = 0	-- minPotentialEnergy
				for k=1,#size do
					potentialEnergy = potentialEnergy + (xs[k] - xmin[k]) * externalForce[k]
				end
				local density = top and 2 or 1
				return buildStateEuler{
					x=x,y=y,z=z,
					noise = .001,
					density = density,
					potentialEnergy = potentialEnergy,
					pressure = 2.5 - density * potentialEnergy,
					-- or maybe it is ... pressure = (gamma - 1) * density * (2.5 - potentialEnergy)
				}
			end
		end,
	},

	-- gravity potential test - equilibrium - Rayleigh-Taylor (still has an shock wave ... need to fix initial conditions?)

	{
		name='self-gravitation test 1',
		equations={'Euler', 'MHD', 'SRHD'},
		setup=function()
			useGravity = true
			boundaryMethods = {{min='FREEFLOW', max='FREEFLOW'}, {min='FREEFLOW', max='FREEFLOW'}, {min='FREEFLOW', max='FREEFLOW'}}
			initState = function(x,y,z)
				return buildSelfGravitationState(x,y,z,{
					sources={
						{center={0, 0, 0}, radius = .2},
					},
				})
			end
		end,
	},

	{
		name='self-gravitation test 1 spinning',
		equations={'Euler', 'MHD', 'SRHD'},
		setup=function()
			useGravity = true
			boundaryMethods = {{min='FREEFLOW', max='FREEFLOW'}, {min='FREEFLOW', max='FREEFLOW'}, {min='FREEFLOW', max='FREEFLOW'}}
			initState = function(x,y,z)
				return buildSelfGravitationState(x,y,z,{
					sources={
						{
							center={0, 0, 0}, 
							radius = .2,
							inside = function(dx,dy,dz)
								return buildStateEuler{
									x=x, y=y, z=z,
									velocityX = -10 * dy,
									velocityY = 10 * dx,
									pressure = 1,
									density = 1,
								}
							end},
					},
				})
			end
		end,
	},

	{
		name='self-gravitation test 2',
		equations={'Euler', 'MHD', 'SRHD'},
		setup=function()
			useGravity = true
			boundaryMethods = {{min='FREEFLOW', max='FREEFLOW'}, {min='FREEFLOW', max='FREEFLOW'}, {min='FREEFLOW', max='FREEFLOW'}}
			initState = function(x,y,z)
				local rho,mx,my,mz,eTotal,bx,by,bz = buildSelfGravitationState(x,y,z,{
					sources={
						{
							center = {-.25, 0, 0},
							radius = .1,
							inside = function(dx,dy,dz)
								return buildStateEuler{
									x=x, y=y, z=z,
									pressure = 1,
									density = 1,
								}
							end,
						},
						{
							center = {.25, 0, 0},
							radius = .1,
							inside = function(dx,dy,dz)
								return buildStateEuler{
									x=x, y=y, z=z,
									pressure = 1,
									density = 1,
								}
							end,
						},
					},
				})
				mx = -5 * rho * y
				my = 5 * rho * x
				return rho,mx,my,mz,eTotal,bx,by,bz
			end
		end,
	},

	{
		name='self-gravitation test 4',
		equations={'Euler', 'MHD', 'SRHD'},
		setup=function()
			useGravity = true
			boundaryMethods = {{min='FREEFLOW', max='FREEFLOW'}, {min='FREEFLOW', max='FREEFLOW'}, {min='FREEFLOW', max='FREEFLOW'}}
			initState = function(x,y,z)
				return buildSelfGravitationState(x,y,z,{
					sources={
						{center={.25, .25, 0}, radius = .1},
						{center={-.25, .25, 0}, radius = .1},
						{center={.25, -.25, 0}, radius = .1},
						{center={-.25, -.25, 0}, radius = .1},
					},
				})
			end
		end,
	},

	{	-- Marti & Muller 2008 
		name='Relativistic Blast Wave Interaction',
		equations={'Euler', 'MHD', 'SRHD'},
		setup=function()
			defs.idealGas_heatCapacityRatio = 7/5
			initState = function(x,y,z)
				local xs = {x,y,z}
				local xlhs = {
					.9 * xmin[1] + .1 * xmax[1],
					.9 * xmin[2] + .1 * xmax[2],
					.9 * xmin[3] + .1 * xmax[3],
				}
				local xrhs = {
					.1 * xmin[1] + .9 * xmax[1],
					.1 * xmin[2] + .9 * xmax[2],
					.1 * xmin[3] + .9 * xmax[3],
				}
		
				-- how should I do this for higher dimensions?  corners?
				local lhs = true
				local rhs = true
				for i=1,#size do
					lhs = lhs and xs[i] <= xlhs[i]
					rhs = rhs and xs[i] >= xrhs[i]
				end
				return buildStateEuler{
					x=x, y=y, z=z,
					density = 1,
					pressure = lhs and 1e+3 or (rhs and 1e+2 or 1e-2),
				}
			end
		end,
	},

	{
		name='Marti & Muller 2008 Problem #1',
		--name = 'SRHD Schneider et al',	-- aka
		equations={'Euler', 'MHD', 'SRHD'},
		setup=function()
			defs.idealGas_heatCapacityRatio=5/3
			initState = function(x,y,z)
				local inside = x <= 0 and y <= 0 and z <= 0
				return buildStateEuler{
					x=x, y=y, z=z,
					density = inside and 10 or 1,
					specificEnergyInternal = inside and 2 or 1e-6,
				}
			end
		end,
	},
	
	{
		name='Marti & Muller 2008 Problem #2',
		equations={'Euler', 'MHD', 'SRHD'},
		setup=function()
			defs.idealGas_heatCapacityRatio = 5/3
			initState = function(x,y,z)
				local inside = x <= 0 and y <= 0 and z <= 0
				return buildStateEuler{
					x=x, y=y, z=z,
					density = 1,
					pressure = inside and 1e+3 or 1e-2,
				}
			end
		end,
	},



	{
		name = 'Relativistic Jet',
		equations = {'Euler', 'MHD', 'SRHD'},
		setup = function()
			defs.idealGas_heatCapacityRatio = 5/3
			initState = function(x,y,z)
				local pressure = 1
				local velocityX = 0
				local height = .05
				local width = (xmax[1] - xmin[1]) / size[1] * 10
				if x < xmin[1] + width
				and y > (.5+height) * xmin[2] + (.5-height) * xmax[2]
				and y < (.5-height) * xmin[2] + (.5+height) * xmax[2]
				then
					local dx = (x - xmin[1]) / width 
					local dy = (y - .5 * (xmax[2] + xmin[2])) / (height * (xmax[2] - xmin[2]))
					local coeff = math.exp(-(dx*dx + dy*dy))
					pressure = pressure + 10 * coeff
					velocityX = .99 * coeff
				end
				return buildStateEuler{
					x = x, y = y, z = z,
					density = 1,
					velocityX = velocityX,
					pressure = pressure,
				}
			end
		end,
	},

		-- Maxwell equations initial state


	{
		name='Maxwell-1',
		equations={'Maxwell'},
		setup=function()
			local epsilon = defs.maxwell_permittivity
			initState = function(x,y,z)
				local inside = x <= 0 and y <= 0 and z <= 0
				local ex = 0 
				local ey = 0
				local ez = 1
				local bx = 0
				local by = 0
				local bz = inside and 1 or -1
				return ex * epsilon, ey * epsilon, ez * epsilon, bx, by, bz
			end
		end,
	},


	-- Numerical Relativity problems: 
	
	
	{
		name='NR Gauge Shock Waves',
		equations={'ADM1D', 'ADM3D', 'BSSNOK'},
		setup=function(args)
			defs.adm_BonaMasso_f = '1. + 1. / (alpha * alpha)'	-- TODO C/OpenCL exporter with lua symmath (only real difference is number formatting, with option for floating point)
			defs.adm_BonaMasso_df_dalpha = '-1. / (alpha * alpha * alpha)'
			print('deriving and compiling...')
			local symmath = require 'symmath'	-- this is failing ...
			local Tensor = symmath.Tensor
			
			local H, sigma
			if not (args and args.unitDomain) then
			-- [[ problem's original domain
				H = 5
				sigma = 10
				xmin = {0, 0, 0}
				xmax = {300, 300, 300}
				camera.zoom = 1/300
				camera.pos = {150,150}
				camera.dist = 450
				graphScale = 300
			--]]
			-- [[ keeping the unit domain (because I'm too lazy to reposition the camera ... and probably numerical stability too)
			else
				H = 1/1000
				sigma = 1/10
			--]]
			end
			local xc = (xmax[1] + xmin[1]) * .5
			local yc = (xmax[2] + xmin[2]) * .5
			local zc = (xmax[3] + xmin[3]) * .5
			local x, y, z = symmath.vars('x', 'y', 'z')
			Tensor.coords{
				{variables={x,y,z}},
			}
			local alpha = symmath.Constant(1)
			local h, gamma, K
	--[[	
			if #size == 1 then
				h = H * symmath.exp(-(x - xc)^2 / sigma^2)
				gamma = Tensor('_ij', 
					{1 - h:diff(x)^2, 0, 0},
					{0, 1, 0},
					{0, 0, 1})
				
				-- keep the upper diagonal half
				-- TODO just forward it as-is to initNumRel and, if anything, add the symmetric storage optimization to symmath
				gamma = {gamma[1][1], gamma[1][2], gamma[1][3], gamma[2][2], gamma[2][3], gamma[3][3]}
				
				K = {
					-h:diff(x,x) / gamma[1]^.5,	--gamma[1] = g_xx
					0,
					0,
					0,
					0,
					0,
				}
			elseif #size == 2 then
				h = H * symmath.exp(-((x - xc)^2 + (y - yc)^2) / sigma^2)
				gamma = {
					1 - h:diff(x)^2,
					-h:diff(x) * h:diff(y),		-- x derivs adds interference, which causes asymmetry, and eventually divergence.  maybe its the influence of D that causes this?
					0,
					1 - h:diff(y)^2,
					0,
					1,
				}
				local div_h = h:diff(x)^2 + h:diff(y)^2
				local K_denom = (1 - div_h)^.5
				K = {
					-h:diff(x,x) / K_denom,
					-h:diff(x,y) / K_denom,
					0,
					-h:diff(y,y) / K_denom,		-- 2nd derivs are nonzero and are causing problems
					0,
					0,
				}
			else
	--]] do
				h = H * symmath.exp(-((x - xc)^2 + (y - yc)^2 + (z - zc)^2) / sigma^2)
				gamma = {
					1 - h:diff(x)^2,
					-h:diff(x) * h:diff(y),
					-h:diff(x) * h:diff(z),
					1 - h:diff(y)^2,
					-h:diff(y) * h:diff(z),
					1 - h:diff(z)^2,
				}
				local div_h = h:diff(x)^2 + h:diff(y)^2 + h:diff(z)^2
				local K_denom = (1 - div_h)^.5
				K = {
					-h:diff(x,x) / K_denom,
					-h:diff(x,y) / K_denom,
					-h:diff(x,z) / K_denom,
					-h:diff(y,y) / K_denom,
					-h:diff(y,z) / K_denom,
					-h:diff(z,z) / K_denom,
				}
			end
		
			print('...done deriving and compiling.')
			
			initNumRel{
				vars = {x,y,z},
				alpha = alpha,
				gamma = gamma,
				K = K,
			}
		end,
	},

	{
		name='NR Alcubierre Warp Bubble',
		equations={'ADM1D', 'ADM3D', 'BSSNOK'},
		setup=function()
			-- [[
			defs.adm_BonaMasso_f = '1. + 1. / (alpha * alpha)'	-- TODO C/OpenCL exporter with lua symmath (only real difference is number formatting, with option for floating point)
			defs.adm_BonaMasso_df_dalpha = '-1. / (alpha * alpha * alpha)'
			--]]
			--[[ constant
			defs.adm_BonaMasso_f = '1.'	-- TODO C/OpenCL exporter with lua symmath (only real difference is number formatting, with option for floating point)
			defs.adm_BonaMasso_df_dalpha = '0.'
			--]]

			xmin = {-2,-2,-2}
			xmax = {2,2,2} 

			local R = 1		-- warp bubble radius
			local sigma = 8	-- warp bubble thickness
			local speed = .1	-- warp bubble speed

			local symmath = require 'symmath'
			local t,x,y,z = symmath.vars('t', 'x', 'y', 'z')
			local x_s = 0 -- speed * t
			local v_s = speed -- x_s:diff(t)()
			local r_s = ((x - x_s)^2 + y^2 + z^2)^.5
			local f = (symmath.tanh(sigma * (r_s + R)) - symmath.tanh(sigma * (r_s - R))) / (2 * symmath.tanh(sigma * R))
		
			local betaUx = -v_s * f

			local alpha = 1

			local K_xx = betaUx:diff(x)() / alpha
			local K_xy = betaUx:diff(y)() / (2 * alpha)
			local K_xz = betaUx:diff(z)() / (2 * alpha)

			initNumRel{
				vars = {x,y,z},
				alpha = alpha,
				
				--[[
				interesting note:
				Alcubierre warp bubble drive depends on a beta parameter
				(the local metric is completely flat)
				however so does the toy 1+1 relativity require a beta parameter to produce the stated extrinsic curvature
				yet the toy 1+1 sample set beta=0
				--]]
				beta = {betaUx, 0, 0},

				gamma = {1, 0, 0, 1, 0, 1},		-- identity
				K = {K_xx, K_xy, K_xz, 0, 0, 0},
			}
		end,
	},

	{
		name='NR Schwarzschild Black Hole',
		equations={'ADM1D', 'ADM3D', 'BSSNOK'},
		setup=function()
			-- [[
			defs.adm_BonaMasso_f = '1. + 1. / (alpha * alpha)'	-- TODO C/OpenCL exporter with lua symmath (only real difference is number formatting, with option for floating point)
			defs.adm_BonaMasso_df_dalpha = '-1. / (alpha * alpha * alpha)'
			--]]
			--[[ constant
			defs.adm_BonaMasso_f = '1.'	-- '1.69'	-- '.49'
			defs.adm_BonaMasso_df_dalpha = '0.'
			--]]
			
			local R = .002	-- Schwarzschild radius
			
			local symmath = require 'symmath'	
			local t,x,y,z = symmath.vars('t','x','y','z')
			local r = (x^2 + y^2 + z^2)^.5
			
			initNumRel{
				vars = {x,y,z},
				-- 4D metric ADM components:
				alpha = (1 - R/r)^.5,
				beta = {0,0,0},
				gamma = {
					x^2/((r/R-1)*r^2) + 1,	-- xx
					x*y/((r/R-1)*r^2),		-- xy
					x*z/((r/R-1)*r^2),		-- xz
					y^2/((r/R-1)*r^2) + 1,	-- yy
					y*z/((r/R-1)*r^2),		-- yz
					z^2/((r/R-1)*r^2) + 1,	-- zz
				},
				K = {0,0,0,0,0,0},
			}
		end,
	},

	{
		name='NR Stellar',
		equations={'ADM1D', 'ADM3D', 'BSSNOK'},
		setup=function(args)
			
			local symmath = require 'symmath'
			symmath.tostring = require 'symmath.tostring.SingleLine'

			--[[ this is technically correct, but gets some artifacts with the radial boundary on the cartesian grid
			local H = symmath.Heaviside
			--]]
			-- [[ this looks a bit smoother.  sharper edges mean greater artifacts.
			local function H(u) return symmath.tanh((u) * 10) * .5 + .5 end
			--]]
				
			local class = require 'ext.class'
			local min = class(require 'symmath.Function')
			min.name = 'min'
			min.func = math.min
			-- derivative wrt 1st param... 
			function min:evaluateDerivative(...)
				local a = self[1]
				local b = self[2]
				return H(b - a) * symmath.diff(a, ...) + H(a - b) * symmath.diff(b, ...)
			end
			
			local bodies = args and args.bodies or {{
				pos = {0,0,0},
				mass = .001,
				radius = .1,
			}}

			defs.adm_BonaMasso_f = '1. + 1. / (alpha * alpha)'	-- TODO C/OpenCL exporter with lua symmath (only real difference is number formatting, with option for floating point)
			defs.adm_BonaMasso_df_dalpha = '-1. / (alpha * alpha * alpha)'
			
			local t,x,y,z = symmath.vars('t','x','y','z')
			
			print('building variables ...')
			
			local alpha = 1
			local gamma = {1,0,0,1,0,1}
			for _,body in ipairs(bodies) do
				local M = body.mass 
				local R = body.radius
				
				local x_ = x - body.pos[1] 
				local y_ = y - body.pos[2] 
				local z_ = z - body.pos[3] 
				local rSq = x_^2 + y_^2 + z_^2
				local r = rSq^.5
				local m = M * min(r/R, 1)^3
				local R = 2*m
				
				alpha = alpha - 2*m/r
				gamma[1] = gamma[1] + x_^2/((r/R-1)*rSq)
				gamma[2] = gamma[2] + x_*y_/((r/R-1)*rSq)
				gamma[3] = gamma[3] + x_*z_/((r/R-1)*rSq)
				gamma[4] = gamma[4] + y_^2/((r/R-1)*rSq)
				gamma[5] = gamma[5] + y_*z_/((r/R-1)*rSq)
				gamma[6] = gamma[6] + z_^2/((r/R-1)*rSq)
			
				-- TODO pressure as well.  see TOV equations: https://en.wikipedia.org/wiki/Tolman%E2%80%93Oppenheimer%E2%80%93Volkoff_equation
			end
			alpha = alpha^.5
			
			print('...done building variables')
			
			print('initializing numerical relativity variables ...')
			initNumRel{
				vars = {x,y,z},
				-- 4D metric ADM components:
				alpha = alpha,
				beta = {0,0,0},
				gamma = gamma,
				K = {0,0,0,0,0,0},
				useNumericInverse = true,	-- if gamma gets too complex ...
				-- hmm would be nice if any field could be a function, algebra, or constant ...
				density = function(x,y,z)
					local density = 0
					for _,body in ipairs(bodies) do
						local x_ = x - body.pos[1] 
						local y_ = y - body.pos[2] 
						local z_ = z - body.pos[3]
						local rSq = x_*x_ + y_*y_ + z_*z_
						if rSq < body.radius * body.radius then
							density = density + (body.density or (body.mass / (4/3 * math.pi * body.radius * body.radius * body.radius)))
						end
					end
					return density
				end,
				pressure = function(x,y,z)
					local pressure = 0
					for _,body in ipairs(bodies) do
						local M = body.mass
						local R = body.radius
						local x_ = x - body.pos[1] 
						local y_ = y - body.pos[2] 
						local z_ = z - body.pos[3]
						local rSq = x_*x_ + y_*y_ + z_*z_
						if rSq < body.radius * body.radius then
							local r = math.sqrt(rSq)
							local rho0 = body.pressure or (body.mass / (4/3 * math.pi * body.radius * body.radius * body.radius))
							-- TOV pressure solution: http://physics.stackexchange.com/questions/69953/solving-the-tolman-oppenheimer-volkoff-tov-equation
							-- ... solution to constant pressure?  doesn't density decrease with radius? time to find a better source.
							pressure = pressure + (body.pressure or (rho0 * (
								(
									math.sqrt(1 - 2 * M / R) - math.sqrt(1 - 2 * M * r * r / (R * R * R))
								) / (
									math.sqrt(1 - 2 * M * r * r / (R * R * R)) - 3 * math.sqrt(1 - 2 * M / R)
								)
							)))
						end
					end
					return pressure
				end,
			}
			print('...done initializing numerical relativity variables') 
		end,
	},
}

-- create a mapping by name as well as index
for _,cond in ipairs(initConds) do
	initConds[cond.name] = cond
end
