/*============================================================================
 * EBU (Eddy Break-Up) gas combustion model.
 *============================================================================*/

/*
  This file is part of code_saturne, a general-purpose CFD tool.

  Copyright (C) 1998-2025 EDF S.A.

  This program is free software; you can redistribute it and/or modify it under
  the terms of the GNU General Public License as published by the Free Software
  Foundation; either version 2 of the License, or (at your option) any later
  version.

  This program is distributed in the hope that it will be useful, but WITHOUT
  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
  FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
  details.

  You should have received a copy of the GNU General Public License along with
  this program; if not, write to the Free Software Foundation, Inc., 51 Franklin
  Street, Fifth Floor, Boston, MA 02110-1301, USA.
*/

/*----------------------------------------------------------------------------*/

#include "base/cs_defs.h"

/*----------------------------------------------------------------------------
 * Standard C library headers
 *----------------------------------------------------------------------------*/

#include <assert.h>
#include <stdio.h>
#include <stdarg.h>
#include <stdlib.h>
#include <string.h>

/*----------------------------------------------------------------------------
 * Local headers
 *----------------------------------------------------------------------------*/

#include "bft/bft_error.h"
#include "bft/bft_printf.h"

#include "base/cs_array.h"
#include "base/cs_array_reduce.h"
#include "base/cs_base.h"
#include "base/cs_field.h"
#include "base/cs_field_pointer.h"
#include "base/cs_physical_constants.h"
#include "base/cs_log.h"
#include "base/cs_math.h"
#include "base/cs_parall.h"
#include "base/cs_physical_properties.h"
#include "base/cs_restart.h"
//#include "base/cs_thermal_model.h"
#include "mesh/cs_mesh.h"

#include "pprt/cs_combustion_model.h"
#include "pprt/cs_physical_model.h"

#include "cogz/cs_combustion_gas.h"
#include "cogz/cs_combustion_boundary_conditions.h"
#include "cogz/cs_combustion_ht_convert.h"

/*----------------------------------------------------------------------------
 * Header for the current file
 *----------------------------------------------------------------------------*/

#include "cogz/cs_combustion_gas.h"
#include "cogz/cs_combustion_ebu.h"

/*----------------------------------------------------------------------------*/

BEGIN_C_DECLS

/*=============================================================================
 * Additional doxygen documentation
 *============================================================================*/

/*!
  \file cs_combustion_ebu.cpp
        Eddy-Break-Up gas combustion model.
*/

/*----------------------------------------------------------------------------*/

/*! \cond DOXYGEN_SHOULD_SKIP_THIS */

/*=============================================================================
 * Macro definitions
 *============================================================================*/

/*============================================================================
 * Type definitions
 *============================================================================*/

/*============================================================================
 * Static global variables
 *============================================================================*/

/*! (DOXYGEN_SHOULD_SKIP_THIS) \endcond */

/*============================================================================
 * Global variables
 *============================================================================*/

/*============================================================================
 * Prototypes for functions intended for use only by Fortran wrappers.
 * (descriptions follow, with function bodies).
 *============================================================================*/

/*============================================================================
 * Private function definitions
 *============================================================================*/

/*============================================================================
 * Fortran wrapper function definitions
 *============================================================================*/

/*! (DOXYGEN_SHOULD_SKIP_THIS) \endcond */

/*=============================================================================
 * Public function definitions
 *============================================================================*/

/*----------------------------------------------------------------------------*/
/*!
 * \brief Initialize specific fields for EBU gas combustion model (first step).
 */
/*----------------------------------------------------------------------------*/

void
cs_combustion_ebu_fields_init0(void)
{
  // Only when not a restart
  if (cs_restart_present())
    return;

  // Local variables

  const cs_lnum_t n_cells_ext = cs_glob_mesh->n_cells_with_ghosts;

  cs_combustion_gas_model_t *cm = cs_glob_combustion_gas_model;
  cs_real_t *cvar_ygfm = cm->ygfm->val;

  cs_real_t coefg[CS_COMBUSTION_GAS_MAX_GLOBAL_SPECIES];
  for (int igg = 0; igg < CS_COMBUSTION_GAS_MAX_GLOBAL_SPECIES; igg++)
    coefg[igg] = 0;

  // Initializations with air at tinitk
  // ----------------------------------

  // Mass fraction of fresh gas
  cs_array_real_set_scalar(n_cells_ext, 1.0, cvar_ygfm);

  // Mixture enthalpy
  if (cm->type % 2 == 1) {
    // mixture temperature: air at tinitk
    cs_real_t tinitk = cs_glob_fluid_properties->t0;

    // Air enthalpy at tinitk
    coefg[0] = 0.;
    coefg[1] = 1.;
    coefg[2] = 0.;
    cs_real_t hair = cs_gas_combustion_t_to_h(coefg, tinitk);

    // Mixture enthalpy
    cs_real_t *cvar_scalt = CS_F_(h)->val;
    cs_array_real_set_scalar(n_cells_ext, hair, cvar_scalt);
  }

  // No need to set fm to 0, as this is the default for all fields.
}

/*----------------------------------------------------------------------------*/
/*!
 * \brief Initialize specific fields for EBU gas combustion model (second step).
 */
/*----------------------------------------------------------------------------*/

void
cs_combustion_ebu_fields_init1(void)
{
  // Only when not a restart
  if (cs_restart_present())
    return;

  // Local variables

  const cs_lnum_t n_cells_ext = cs_glob_mesh->n_cells_with_ghosts;

  cs_combustion_gas_model_t *cm = cs_glob_combustion_gas_model;
  const int sub_type = cm->type % 100;

  cs_real_t *cvar_ygfm = cm->ygfm->val;

  cs_real_t coefg[CS_COMBUSTION_GAS_MAX_GLOBAL_SPECIES];
  for (int igg = 0; igg < CS_COMBUSTION_GAS_MAX_GLOBAL_SPECIES; igg++)
    coefg[igg] = 0;

  // Preliminary computations: mixture fraction, T, H

  cs_real_t fmelm, tentm;
  cs_combustion_boundary_conditions_mean_inlet_ebu_lw(&fmelm, &tentm);

  // Mass fraction of fresh gas
  cs_array_real_set_scalar(n_cells_ext, 0.5, cvar_ygfm);

  // Mixture fraction
  if (sub_type == 2 || sub_type == 3) {
    cs_real_t *cvar_fm = cm->fm->val;
    cs_array_real_set_scalar(n_cells_ext, fmelm, cvar_fm);
  }

  // Mixture enthalpy
  if (cm->type %2 == 1) {
    coefg[0] = fmelm;
    coefg[1] = (1.-fmelm);
    coefg[2] = 0.;
    cs_real_t hinit = cs_gas_combustion_t_to_h(coefg, tentm);
    cs_real_t *cvar_scalt = CS_F_(h)->val;
    cs_array_real_set_scalar(n_cells_ext, hinit, cvar_scalt);
  }

  // Logging
  // -------

  const cs_lnum_t n_cells = cs_glob_mesh->n_cells;

  cs_log_printf(CS_LOG_DEFAULT, "\n");
  cs_log_separator(CS_LOG_DEFAULT);

  cs_log_printf
    (CS_LOG_DEFAULT,
     _("\n"
       " ** INITIALIZATION OF EBU MODEL VARIABLES (FL PRE EBU)\n"
       "    --------------------------------------------------\n"
       "\n"
       " ---------------------------------\n"
       "  Variable  Min. value  Max. value\n"
       " ---------------------------------\n"));

  // Model scalars only

  const int n_fields = cs_field_n_fields();
  const int keysca = cs_field_key_id("scalar_id");

  for (int ii = 0; ii < n_fields; ii++) {
    cs_field_t *f_scal = cs_field_by_id(ii);

    if (!(f_scal->type & CS_FIELD_VARIABLE))
      continue;
    if (cs_field_get_key_int(f_scal, keysca) <= 0)
      continue;
    if (f_scal->type & CS_FIELD_USER)
      continue;

    cs_real_t vmin = HUGE_VALF, vmax = -HUGE_VALF;
    cs_array_reduce_minmax(n_cells, f_scal->val, vmin, vmax);

    cs_parall_min(1, CS_REAL_TYPE, &vmin);
    cs_parall_max(1, CS_REAL_TYPE, &vmax);

    cs_log_printf(CS_LOG_DEFAULT,
                  "  %8s  %12.4e  %12.4e\n",
                  f_scal->name, vmin, vmax);
  }

  cs_log_printf(CS_LOG_DEFAULT, "\n");
  cs_log_separator(CS_LOG_DEFAULT);
}

/*----------------------------------------------------------------------------*/

END_C_DECLS
