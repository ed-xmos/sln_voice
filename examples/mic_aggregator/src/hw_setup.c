// Copyright 2023 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#include <stdio.h>
#include <xs1.h>
#include <xcore/port.h>
#include <xcore/hwtimer.h>
#include "app_config.h"

// This contains code for the setup of the XK-AUDIO-316-MC board VERSION 1.0 ONLY!!

void hw_setup(void){
    printf("HW SETUP\n");

    port_enable(XS1_PORT_1N); // Ensure input for spdif_coax_rx
    port_in(XS1_PORT_1N);
    port_enable(XS1_PORT_1O); // Ensure input for ada_opt_rx
    port_in(XS1_PORT_1O);
    port_enable(XS1_PORT_1P); // Ensure input for word_clock_in
    port_in(XS1_PORT_1P);

    hwtimer_t tmr = hwtimer_alloc();
    port_t p_hw_ctl = XU316_MC_CTRL_PORT;
    port_enable(p_hw_ctl);

    const uint8_t use_xmos_mclk = 0x80; // Set so that XCORE drives the MCLK

    for (int i = 0; i < 30; i++)
    {
        port_out(p_hw_ctl, use_xmos_mclk | 0x30); /* 3v3: off, 3v3A: on */
        hwtimer_delay(tmr, 5 * XS1_TIMER_MHZ);
        port_out(p_hw_ctl, use_xmos_mclk | 0x20); /* 3v3: on, 3v3A: on */
        hwtimer_delay(tmr, 5 * XS1_TIMER_MHZ);
    }
    hwtimer_free(tmr);
}
