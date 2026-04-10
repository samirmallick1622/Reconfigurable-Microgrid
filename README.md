# Reconfigurable-converter

# Overview

This project presents a reconfigurable power electronic converter developed in MATLAB Simulink, capable of operating as both a rectifier and an inverter. The same circuit topology is used for dual operation, with functionality determined by a selectable mode.

MOSFETs are used as switching devices instead of IGBTs, making the design suitable for faster switching applications and lower power levels.

# Working Principle
In rectifier mode, the circuit converts a three-phase AC input into DC output using controlled switching.

In inverter mode, the circuit converts DC input into AC output using PWM-based gate signals.

A mode selection mechanism controls the switching logic and determines the direction of power conversion.

# Key Features

Dual operation using a single circuit (rectifier and inverter)
MOSFET-based switching
PWM control for inverter operation
Mode selection through control logic
Output monitoring using scopes

# Components Used
Three-phase AC source
MOSFET switches
PWM Generator (Three-phase)
RL load / DC load
DC link capacitor
Voltage and current measurement blocks
Powergui (Discrete)

# Tools and Software
MATLAB Simulink
Simscape Electrical

# How to Run
Open the .slx file in MATLAB Simulink
Ensure required toolboxes (Simscape Electrical) are installed
Select mode:
0 for inverter operation
1 for rectifier operation
Run the simulation
Observe output waveforms using scope blocks

# Results
Rectifier mode produces a DC output with reduced ripple due to filtering
Inverter mode generates an AC waveform using PWM switching
Output characteristics depend on switching frequency and load parameters

# Learning Outcomes
Understanding of bidirectional power conversion
Implementation of PWM-based switching
Practical differences between MOSFET and IGBT usage
Modeling of power electronic systems in Simulink

# Future Improvements
Addition of closed-loop control (PI controller)
Output waveform improvement using filters
Hardware implementation
Fault detection and protection mechanisms

# Author

Samir Mallick
Electrical Engineering, NIT Patna
