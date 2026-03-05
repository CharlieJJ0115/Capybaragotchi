# CapybaraGotchi 🦫🎮

A digital pet game implemented on FPGA, inspired by Tamagotchi, featuring a capybara-themed interactive experience.

This project was developed for **CS2104 Hardware Design Lab**.

---
## Demo Video 🎥

[![CapybaraGotchi Demo](https://img.youtube.com/vi/ZWOgOFY7l-o/0.jpg)](https://www.youtube.com/watch?v=ZWOgOFY7l-o)
# Project Overview

CapybaraGotchi is a handheld electronic pet game built on FPGA.  
Players interact with a capybara using a joystick and ultrasonic sensor while viewing animations on an LCD screen.

The system is implemented using **Verilog** and designed as a collection of **finite state machines (FSMs)** controlling the pet’s behavior, scenes, and user interface.

---

# Features

## Pet States
The capybara can perform several behaviors:

- Idle
- Sleep
- Walk
- Feed
- Sick
- Clean
- Touch interaction

Each state has its own animation displayed on the LCD.

---

## Gameplay
Players can interact with the capybara through different activities:

- Feed the capybara
- Clean after it
- Interact using joystick
- Play a mini-game

---

## Additional Features

Additional features implemented in the project:

- Weather system
- Hot spring event
- Different foods depending on weather
- Hunger system
- Life system

---

# Hardware Components

The system integrates several hardware modules:

- FPGA board
- LCD display
- Joystick (player control)
- Ultrasonic sensor (touch detection)
- 3D printed handheld case

---

# System Architecture

The project is structured around three major **finite state machines (FSMs)**.

## 1. Scene FSM

Controls the main scenes of the game:

- DEFAULT
- HOTSPRING
- POOPING
- PLAY (mini game)
- GAME END

---

## 2. Capybara State FSM

Controls the capybara’s behavior:

- IDLE
- SLEEP
- WALK
- FEED
- TOUCH

Each state corresponds to a different animation displayed on the screen.

---

## 3. Lower Screen FSM

Controls the UI displayed at the bottom of the screen:

- INIT (status display)
- MENU
- SELECT_FOOD
- CLEAN

---

# Animation System

Animations are implemented using:

- Frame controller
- BRAM stored sprite frames
- Address generators for sprite positioning

The capybara sprite can move across the screen, turn direction, and perform animations by switching between frames stored in BRAM.

---

# Mini Game

A mini-game is included in the PLAY scene.

Gameplay mechanics:

- The player controls a cup using the joystick
- A ball bounces around the screen
- The player must catch the ball with the capybara's head
- Missing the ball results in game over

Collision detection and movement logic are implemented in Verilog.

---

# Mechanical Design

The handheld device uses a **three-layer 3D printed structure**:

1. Top layer – LCD and joystick mount  
2. Middle layer – structural support and wiring path  
3. Bottom layer – FPGA board and ultrasonic sensor  

The case design allows easy assembly and maintenance.

---

# Technologies Used

- Verilog HDL
- FPGA development (Vivado)
- BRAM for sprite storage
- LCD SPI interface
- Joystick input module
- Ultrasonic sensor module

---

# Team

Team 18 – HardcoreDesign

Members:
- 江善有
- 林亮宏

## Contribution

The project was developed collaboratively with an approximate **50 / 50 contribution split**.

- **江善有**  
  Responsible for the main Verilog implementation, including the top module, FSM design, and overall system logic.

- **林亮宏**  
  Responsible for sprite/animation image generation (COE files), joystick module implementation, and assisting with debugging and testing.

Both members collaborated on system design discussions and hardware integration.

# Acknowledgements

Some modules were adapted from existing resources:

- SPI LCD module (online resources)
- Digilent joystick reference
- Ultrasonic sensor module from lab materials
