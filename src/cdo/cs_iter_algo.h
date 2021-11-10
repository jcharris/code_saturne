#ifndef __CS_ITER_ALGO_H__
#define __CS_ITER_ALGO_H__

/*============================================================================
 * Set of functions to manage high-level iterative algorithms
 *============================================================================*/

/*
  This file is part of Code_Saturne, a general-purpose CFD tool.

  Copyright (C) 1998-2021 EDF S.A.

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

/*----------------------------------------------------------------------------
 *  Local headers
 *----------------------------------------------------------------------------*/

#include "cs_math.h"
#include "cs_sles.h"

/*----------------------------------------------------------------------------*/

BEGIN_C_DECLS

/*============================================================================
 * Macro definitions
 *============================================================================*/

/*============================================================================
 * Type definitions
 *============================================================================*/

/*! \struct cs_iter_algo_info_t
 *  \brief Information related to the convergence of an iterative algorithm
 *
 *  Metadata to manage an iterative algorithm such as Picard or Uzawa for
 *  instance. This structure can handle embedded iterative algorithm since the
 *  notion of inner and outer iterations is defined. Nevertheless, only the
 *  outer iterative algorithm is managed (information about inner iterations
 *  are only for monitoring purposes).
 */

typedef struct {

/*!
 * @name Generic parameters
 * @{
 *
 * \var verbosity
 * Level of printed information
 *
 * \var context
 * pointer to structure cast on the fly
 *
 * @}
 * @name Stoppping criteria
 * Set of tolerances to drive the convergence of the iterative algorithm or
 * max. number of iterations
 * @{
 *
 * \var n_max_algo_iter
 * Maximal number of iterations for the algorithm
 *
 * \var atol
 * Absolute tolerance
 *
 * \var rtol
 * Relative tolerance
 *
 * \var dtol
 * Tolerance to detect a divergence of the algorithm. Not used if < 0
 *
 * @}
 * @name Convergence indicators
 * @{
 *
 * \var cvg
 * Converged, iterating or diverged status
 *
 * \var res
 * Value of the residual for the iterative algorithm
 *
 * \var res0
 * Initial value of the residual for the iterative algorithm
 *
 * \var tol
 * Tolerance computed as tol = max(atol, res0*rtol) where
 * atol and rtol are respectively the absolute and relative tolerance associated
 * to the algorithm
 *
 * \var n_algo_iter
 * Current number of iterations for the algorithm (outer iterations)
 *
 * \var n_inner_iter
 * Curent cumulated number of inner iterations (sum over the outer iterations)
 *
 * \var last_inner_iter
 * Last number of iterations for the inner solver
 *
 * @}
 */

  int                              verbosity;
  void                            *context;

  int                              n_max_algo_iter;
  double                           atol;
  double                           rtol;
  double                           dtol;

  cs_sles_convergence_state_t      cvg;
  double                           res;
  double                           res0;
  double                           tol;

  int                              n_algo_iter;
  int                              n_inner_iter;
  int                              last_inner_iter;

} cs_iter_algo_info_t;

/*============================================================================
 * Inline static public function prototypes
 *============================================================================*/

/*----------------------------------------------------------------------------*/
/*!
 * \brief  Reset a cs_iter_algo_info_t structure
 *
 * \param[in, out]  info   pointer to a cs_iter_algo_info_t
 */
/*----------------------------------------------------------------------------*/

static inline void
cs_iter_algo_reset(cs_iter_algo_info_t    *info)
{
  if (info == NULL)
    return;

  info->cvg = CS_SLES_ITERATING;
  info->res = cs_math_big_r;
  info->n_algo_iter = 0;
  info->n_inner_iter = 0;
  info->last_inner_iter = 0;
}

/*----------------------------------------------------------------------------*/
/*!
 * \brief  Print header before dumping information gathered in the structure
 *         cs_iter_algo_info_t
 *
 * \param[in]  algo_name     name of the algorithm
 */
/*----------------------------------------------------------------------------*/

static inline void
cs_iter_algo_navsto_print_header(const char   *algo_name)
{
  assert(algo_name != NULL);
  cs_log_printf(CS_LOG_DEFAULT,
                "%12s.It  -- Algo.Res   Inner  Cumul  ||div(u)||  Tolerance\n",
                algo_name);
}

/*----------------------------------------------------------------------------*/
/*!
 * \brief  Print header before dumping information gathered in the structure
 *         cs_iter_algo_info_t
 *
 * \param[in]  algo_name     name of the algorithm
 * \param[in]  info          pointer to cs_iter_algo_info_t structure
 * \param[in]  div_l2        l2 norm of the divergence
 */
/*----------------------------------------------------------------------------*/

static inline void
cs_iter_algo_navsto_print(const char                    *algo_name,
                          const cs_iter_algo_info_t     *info,
                          double                         div_l2)
{
  assert(algo_name != NULL);
  cs_log_printf(CS_LOG_DEFAULT,
                "%12s.It%02d-- %5.3e  %5d  %5d  %6.4e  %6.4e\n",
                algo_name, info->n_algo_iter, info->res,
                info->last_inner_iter, info->n_inner_iter, div_l2, info->tol);
  cs_log_printf_flush(CS_LOG_DEFAULT);
}

/*============================================================================
 * Public function prototypes
 *============================================================================*/

/*----------------------------------------------------------------------------*/
/*!
 * \brief  Create and initialize a new cs_iter_algo_info_t structure
 *
 * \param[in] verbosity    set the level of information printed
 * \param[in] n_max_iter   maximal number of iteration
 * \param[in] atol         absolute tolerance
 * \param[in] rtol         relative tolerance
 * \param[in] dtol         divergence tolerance
 *
 * \return a pointer to the new allocated structure
 */
/*----------------------------------------------------------------------------*/

cs_iter_algo_info_t *
cs_iter_algo_define(int          verbosity,
                    int          n_max_iter,
                    double       atol,
                    double       rtol,
                    double       dtol);

/*----------------------------------------------------------------------------*/
/*!
 * \brief  Check if something wrong happens during the iterative process
 *
 * \param[in] func_name    name of the calling function
 * \param[in] eq_name      name of the equation being solved
 * \param[in] algo_name    name of the iterative algo. used
 * \param[in] iai          pointer to the iterative algo. structure
 */
/*----------------------------------------------------------------------------*/

void
cs_iter_algo_check(const char            *func_name,
                   const char            *eq_name,
                   const char            *algo_name,
                   cs_iter_algo_info_t   *iai);

/*----------------------------------------------------------------------------*/
/*!
 * \brief  Test if one has to do one more Picard iteration.
 *         Test if performed on the relative norm on the increment between
 *         two iterations but also on the divergence.
 *
 * \param[in]      pre_iterate    previous state of the mass flux iterate
 * \param[in]      cur_iterate    current state of the mass flux iterate
 * \param[in]      div_l2_norm    L2 norm of the velocity divergence
 * \param[in, out] a_info         pointer to a cs_iter_algo_info_t struct.
 *
 * \return the convergence state
 */
/*----------------------------------------------------------------------------*/

cs_sles_convergence_state_t
cs_iter_algo_navsto_fb_picard_cvg(const cs_real_t             *pre_iterate,
                                  const cs_real_t             *cur_iterate,
                                  cs_real_t                    div_l2_norm,
                                  cs_iter_algo_info_t         *a_info);

/*----------------------------------------------------------------------------*/

END_C_DECLS

#endif /* __CS_ITER_ALGO_H__ */
