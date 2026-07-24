// TODO: make this an object and add current_settings and default_settings

/// Image rendering debug modes
pub const DebugMode = enum {
    /// The actual render will be the output
    none,
    /// The output colors objects depending on the material ID
    material_ids,
    /// The normal of the hit point will be used with xyz as rgb
    normal,
    /// The direction of reflection vectors will be used with xyz as rgb
    reflection,
    /// The number of steps is used to color
    rayinfo,
};

/// Distance from an object at which we consider we hit it
pub var hit_distance: f64 = 0.02;
/// Number of steps forward a ray can take before giving up
pub var max_steps: usize = 1024;
/// Number of steps forward a ray can take before giving up, when it's getting closer to something
/// Larger value because we don't want to give up as easily when theres probably somehting
pub var max_steps_getting_closer: usize = 2048;
/// Number of recursive reflections a ray can have
pub var max_reflections: u8 = 6;
/// Preview mode: will alter other settings
pub var preview: bool = false;
/// Changes what the output image will represent (see DebugMode)
pub var debug_mode: DebugMode = .rayinfo;
/// Enables benchmark mode, no image will be generated, some parameters
/// will be changed and rendering will happen benchmark_it times after a warmup
pub var benchmark: bool = false;
/// Number of renders we perform when benchmark is true
pub var benchmark_it: usize = 5;
/// Output info of the rays of a rayload at each update
/// Slows down everything!!! only for analysis
pub var report_rayload_composition = true;
/// Width of the image output in pixels (doesn't apply when benchmarking)
pub var pic_width: usize = 1000;
/// Height of the image output in pixels (doesn't apply when benchmarking)
pub var pic_height: usize = 1000;
/// Max x,y,z coordinates until a ray is given up on
pub var scene_boundaries: f32 = 100;
