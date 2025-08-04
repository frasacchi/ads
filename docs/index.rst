Aeroelastic Development Suite (ADS)
=================================================
Welcome to the Aeroelastic Development Suite (ADS) documentation!

This package includes a set of tools to:
- Build *fe* models
- Run calculations in nastran using these *fe* models
- Build *fe* models from BAFF models

Building From BAFF models
-------------------------------------------------
To build *fe* models from BAFF models, you can use the `ads.baff.baff2fe` command. This command will convert BAFF models into finite element models that can be used in Nastran calculations.

The optional argumetn of `ads.baff.baff2fe` is an instance of the class `ads.baff.baffOpts`, which defines options for the conversion process, ses the API reference for the availble options. 

Running Nastran Calculations
-------------------------------------------------

see the examples folders for running Nastran simulations. Currently there si support for the following solution types:
- **Sol101**: Static analysis
- **Sol103**: Modal analysis
- **Sol111**: Fatigue Analysis (incomplete)
- **Sol144**: Static Aeroelastic analysis
- **Sol145**: Dynamic Aeroelastic analysis
- **Sol146**: Transient Aeroelastic Analysis (gusts or turbulence)
- **Divergence**: Divergence Analysis

  