#include "utils.h"
#include "variable.h"

namespace poc {

static float inner_product(float2 a, float2 b) {
    return a.x * b.x + a.y * b.y;
}

bool obb_test(const float2 p,
              const int tx, const int ty,
              const float2 eigen_vec1, const float2 eigen_vec2,
              const float eigen_val1, const float eigen_val2,
              const float tile_size) {
    float2 aabb_pivot = {tx * tile_size + tile_size / 2.0f, ty * tile_size + tile_size / 2.0f};
    float2 l = {aabb_pivot.x - p.x, aabb_pivot.y - p.y};
    float aabb_width = tile_size / 2.0f;
    float aabb_height = tile_size / 2.0f;

    float2 axes[4] = {
        {1, 0},
        {0, 1},
        {eigen_vec1.x, eigen_vec1.y},
        {eigen_vec2.x, eigen_vec2.y}};

    float r1, r2, r3, r4;
    r1 = fabs(eigen_val1 * axes[2].x);
    r2 = fabs(eigen_val2 * axes[3].x);
    r3 = aabb_width;
    if (r1 + r2 + r3 <= fabs(l.x))
        return false;

    r1 = fabs(eigen_val1 * axes[2].y);
    r2 = fabs(eigen_val2 * axes[3].y);
    r3 = aabb_height;
    if (r1 + r2 + r3 <= fabs(l.y))
        return false;

    r1 = fabs(eigen_val1);
    r2 = 0;
    r3 = fabs(aabb_width * axes[2].x);
    r4 = fabs(aabb_height * axes[2].y);
    if (r1 + r2 + r3 + r4 <= fabs(inner_product(l, axes[2])))
        return false;

    r1 = 0;
    r2 = fabs(eigen_val2);
    r3 = fabs(aabb_width * axes[3].x);
    r4 = fabs(aabb_height * axes[3].y);
    if (r1 + r2 + r3 + r4 <= fabs(inner_product(l, axes[3])))
        return false;

    return true;
}

} // namespace poc
