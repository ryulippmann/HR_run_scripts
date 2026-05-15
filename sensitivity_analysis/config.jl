# sensitivity_analysis/config.jl
# Single source of truth for all sensitivity runs.
# include("config.jl") at the top of each runscript.

import HierarchicalRouting as HR
using HierarchicalRouting
using ProgressMeter

const SUBSET_PATH = "data/site/Moore_2024-02-14b_v060_rc1.gpkg"
const BATHY_PATH = "data/env_constraints/bathy/Cairns-Cooktown_bathy.tif"
const WAVE_DISTURBANCE_PATH = "data/env_disturbances/waves/output_slope_zs_Hs_Tp.geojson"
const DEPOT = (146.175, -16.84)
const DRAFT_MS = -5.0
const DRAFT_T = -2.0
const N_TARGET_PTS = 29
const BUFFER_DIST = 1E-3

const N_INSTANCES = 100
const SOLVE_SEED = 1234

const waypoint_optim_method = HR.Optim.ParticleSwarm(n_particles=6)

const PLOT_FLAG = false
const INFO_FLAG = false
const SAVE_PLOTS = false  # set true only for small N_INSTANCES runs

if PLOT_FLAG || SAVE_PLOTS
    using HierarchicalRouting.CairoMakie
    CairoMakie.activate!(type="png")
end

# ── Per-analysis sweep parameters ─────────────────────────────────────────────
# Fixed defaults (overridden where swept)
const WEIGHT_MS = 0.2
const WEIGHT_T = 0.1
const N_TENDERS = 3
const T_CAP = 2

# ── Cluster sweep bounded by N_TARGET_PTS (nc must be <= n_targets) ───────────
const CLUSTER_SWEEP = vcat(3:8, 10:2:(N_TARGET_PTS÷2))

# ── Tender fleet configs: (n_tenders, capacity) —──────────────────────────────
const TENDER_CONFIGS = collect(zip([6, 3, 2, 1], reverse([6, 3, 2, 1])))

# ── Weighting sweep ───────────────────────────────────────────────────────────
const WEIGHTS_MS = collect(0.1:0.1:0.5)
const WEIGHTS_T = collect(0.05:0.01:0.1)
const WEIGHT_CONFIGS = collect(Iterators.product(WEIGHTS_MS, WEIGHTS_T))
