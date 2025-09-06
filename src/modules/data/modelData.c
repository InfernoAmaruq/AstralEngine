#include "data/modelData.h"
#include "data/blob.h"
#include "data/image.h"
#include "core/maf.h"
#include "util.h"
#include <stdlib.h>
#include <string.h>

static void* nullIO(const char* path, size_t* count) {
  return NULL;
}

ModelData* lovrModelDataCreate(Blob* source, ModelDataIO* io) {
  if (!io) io = &nullIO;

  ModelData* model = NULL;
  if (!model && !lovrModelDataInitGltf(&model, source, io)) return false;
  if (!model && !lovrModelDataInitObj(&model, source, io)) return false;
  if (!model && !lovrModelDataInitStl(&model, source, io)) return false;

  if (!model) {
    lovrSetError("Unable to load model from '%s'", source->name);
    return NULL;
  }

  return model;
}

void lovrModelDataDestroy(void* ref) {
  ModelData* model = ref;
  for (uint32_t i = 0; model->images && i < model->imageCount; i++) {
    lovrRelease(model->images[i], lovrImageDestroy);
  }
  map_free(model->blendShapeMap);
  map_free(model->animationMap);
  map_free(model->materialMap);
  map_free(model->nodeMap);
  lovrFree(model->triangleVertices);
  lovrFree(model->triangleIndices);
  lovrFree(model->vertices);
  lovrFree(model->indices);
  lovrFree(model->skinData);
  lovrFree(model->blendData);
  lovrFree(model->metadata);
  lovrFree(model->data);
  lovrFree(model);
}

// Batches allocations for all the ModelData arrays
void lovrModelDataAllocate(ModelData* model) {
  size_t totalSize = 0;
  size_t sizes[16];
  size_t alignment = 8;
  totalSize += sizes[0] = ALIGN(model->imageCount * sizeof(Image*), alignment);
  totalSize += sizes[1] = ALIGN(model->meshCount * sizeof(ModelMesh), alignment);
  totalSize += sizes[2] = ALIGN(model->materialCount * sizeof(ModelMaterial), alignment);
  totalSize += sizes[3] = ALIGN(model->blendShapeCount * sizeof(ModelBlendShape), alignment);
  totalSize += sizes[4] = ALIGN(model->animationCount * sizeof(ModelAnimation), alignment);
  totalSize += sizes[5] = ALIGN(model->skinCount * sizeof(ModelSkin), alignment);
  totalSize += sizes[6] = ALIGN(model->nodeCount * sizeof(ModelNode), alignment);
  totalSize += sizes[7] = ALIGN(model->primitiveCount * sizeof(ModelPrimitive), alignment);
  totalSize += sizes[8] = ALIGN(model->channelCount * sizeof(ModelAnimationChannel), alignment);
  totalSize += sizes[9] = ALIGN(model->jointCount * 16 * sizeof(float), alignment);
  totalSize += sizes[10] = ALIGN(model->jointCount * sizeof(uint32_t), alignment);
  totalSize += sizes[11] = ALIGN(model->charCount * sizeof(char), alignment);
  totalSize += sizes[12] = ALIGN(sizeof(map_t), alignment);
  totalSize += sizes[13] = ALIGN(sizeof(map_t), alignment);
  totalSize += sizes[14] = ALIGN(sizeof(map_t), alignment);
  totalSize += sizes[15] = ALIGN(sizeof(map_t), alignment);

  size_t offset = 0;
  char* p = model->data = lovrCalloc(totalSize);
  model->images = (Image**) (p + offset), offset += sizes[0];
  model->meshes = (ModelMesh*) (p + offset), offset += sizes[1];
  model->materials = (ModelMaterial*) (p + offset), offset += sizes[2];
  model->blendShapes = (ModelBlendShape*) (p + offset), offset += sizes[3];
  model->animations = (ModelAnimation*) (p + offset), offset += sizes[4];
  model->skins = (ModelSkin*) (p + offset), offset += sizes[5];
  model->nodes = (ModelNode*) (p + offset), offset += sizes[6];
  model->primitives = (ModelPrimitive*) (p + offset), offset += sizes[7];
  model->channels = (ModelAnimationChannel*) (p + offset), offset += sizes[8];
  model->inverseBindMatrices = (float*) (p + offset), offset += sizes[9];
  model->joints = (uint32_t*) (p + offset), offset += sizes[10];
  model->chars = (char*) (p + offset), offset += sizes[11];
  model->blendShapeMap = (map_t*) (p + offset), offset += sizes[12];
  model->animationMap = (map_t*) (p + offset), offset += sizes[13];
  model->materialMap = (map_t*) (p + offset), offset += sizes[14];
  model->nodeMap = (map_t*) (p + offset), offset += sizes[15];

  model->vertices = model->vertexCount > 0 ? lovrMalloc(model->vertexCount * sizeof(ModelVertex)) : NULL;
  model->indices = model->indexCount > 0 ? lovrMalloc(model->indexCount * model->indexSize) : NULL;
  model->skinData = model->skinnedVertexCount > 0 ? lovrMalloc(model->skinnedVertexCount * sizeof(SkinData)) : NULL;
  model->blendData = model->blendedVertexCount > 0 ? lovrMalloc(model->blendedVertexCount * sizeof(BlendData)) : NULL;

  map_init(model->blendShapeMap, model->blendShapeCount);
  map_init(model->animationMap, model->animationCount);
  map_init(model->materialMap, model->materialCount);
  map_init(model->nodeMap, model->nodeCount);

  for (uint32_t i = 0; i < model->primitiveCount; i++) {
    model->primitives[i].mode = DRAW_TRIANGLE_LIST;
    model->primitives[i].material = ~0u;
  }

  for (uint32_t i = 0; i < model->materialCount; i++) {
    model->materials[i] = (ModelMaterial) {
      .color = { 1.f, 1.f, 1.f, 1.f },
      .glow = { 0.f, 0.f, 0.f, 1.f },
      .uvShift = { 0.f, 0.f },
      .uvScale = { 1.f, 1.f },
      .metalness = 1.f,
      .roughness = 1.f,
      .clearcoat = 0.f,
      .clearcoatRoughness = 0.f,
      .occlusionStrength = 1.f,
      .normalScale = 1.f,
      .alphaCutoff = 0.f,
      .texture = ~0u,
      .glowTexture = ~0u,
      .metalnessTexture = ~0u,
      .roughnessTexture = ~0u,
      .clearcoatTexture = ~0u,
      .occlusionTexture = ~0u,
      .normalTexture = ~0u
    };
  }

  for (uint32_t i = 0; i < model->nodeCount; i++) {
    vec3_set(model->nodes[i].transform.translation, 0.f, 0.f, 0.f);
    quat_identity(model->nodes[i].transform.rotation);
    vec3_set(model->nodes[i].transform.scale, 1.f, 1.f, 1.f);
    model->nodes[i].hasMatrix = false;
    model->nodes[i].child = ~0u;
    model->nodes[i].sibling = ~0u;
    model->nodes[i].parent = ~0u;
    model->nodes[i].mesh = ~0u;
    model->nodes[i].skin = ~0u;
  }
}

bool lovrModelDataFinalize(ModelData* model) {
  for (uint32_t i = 0; i < model->meshCount; i++) {
    uint32_t skin = ~0u;
    for (uint32_t j = 0; j < model->nodeCount; j++) {
      if (model->nodes[j].mesh == i) {
        if (skin == ~0u) {
          skin = model->nodes[j].skin;
        } else {
          lovrAssert(model->nodes[j].skin == skin, "Model has mesh used with multiple different skins, which is not currently supported");
        }
      }
    }
  }

  return true;
}

static void boundingBoxHelper(ModelData* model, uint32_t nodeIndex, float* parentTransform) {
  ModelNode* node = &model->nodes[nodeIndex];

  float m[16];
  mat4_init(m, parentTransform);

  if (node->hasMatrix) {
    mat4_mul(m, node->transform.matrix);
  } else {
    float* T = node->transform.translation;
    float* R = node->transform.rotation;
    float* S = node->transform.scale;
    mat4_fromPose(m, T, R);
    mat4_scale(m, S[0], S[1], S[2]);
  }

  if (node->mesh != ~0u) {
    ModelMesh* mesh = &model->meshes[node->mesh];

    for (uint32_t i = 0; i < mesh->primitiveCount; i++) {
      ModelPrimitive* primitive = &mesh->primitives[i];

      float xmin = primitive->bounds[0], xmax = primitive->bounds[1];
      float ymin = primitive->bounds[2], ymax = primitive->bounds[3];
      float zmin = primitive->bounds[4], zmax = primitive->bounds[5];

      float xa[3] = { xmin * m[0], xmin * m[1], xmin * m[2] };
      float xb[3] = { xmax * m[0], xmax * m[1], xmax * m[2] };

      float ya[3] = { ymin * m[4], ymin * m[5], ymin * m[6] };
      float yb[3] = { ymax * m[4], ymax * m[5], ymax * m[6] };

      float za[3] = { zmin * m[8], zmin * m[9], zmin * m[10] };
      float zb[3] = { zmax * m[8], zmax * m[9], zmax * m[10] };

      float min[3] = {
        MIN(xa[0], xb[0]) + MIN(ya[0], yb[0]) + MIN(za[0], zb[0]) + m[12],
        MIN(xa[1], xb[1]) + MIN(ya[1], yb[1]) + MIN(za[1], zb[1]) + m[13],
        MIN(xa[2], xb[2]) + MIN(ya[2], yb[2]) + MIN(za[2], zb[2]) + m[14]
      };

      float max[3] = {
        MAX(xa[0], xb[0]) + MAX(ya[0], yb[0]) + MAX(za[0], zb[0]) + m[12],
        MAX(xa[1], xb[1]) + MAX(ya[1], yb[1]) + MAX(za[1], zb[1]) + m[13],
        MAX(xa[2], xb[2]) + MAX(ya[2], yb[2]) + MAX(za[2], zb[2]) + m[14]
      };

      model->boundingBox[0] = MIN(model->boundingBox[0], min[0]);
      model->boundingBox[1] = MAX(model->boundingBox[1], max[0]);
      model->boundingBox[2] = MIN(model->boundingBox[2], min[1]);
      model->boundingBox[3] = MAX(model->boundingBox[3], max[1]);
      model->boundingBox[4] = MIN(model->boundingBox[4], min[2]);
      model->boundingBox[5] = MAX(model->boundingBox[5], max[2]);
    }
  }

  for (uint32_t i = node->child; i != ~0u; i = model->nodes[i].sibling) {
    boundingBoxHelper(model, i, m);
  }
}

void lovrModelDataGetBoundingBox(ModelData* model, float box[6]) {
  if (model->boundingBox[1] - model->boundingBox[0] == 0.f) {
    boundingBoxHelper(model, model->rootNode, (float[16]) MAT4_IDENTITY);
  }

  memcpy(box, model->boundingBox, sizeof(model->boundingBox));
}

static void boundingSphereHelper(ModelData* model, uint32_t nodeIndex, uint32_t* pointIndex, float* points, float* parentTransform) {
  ModelNode* node = &model->nodes[nodeIndex];

  float m[16];
  mat4_init(m, parentTransform);

  if (node->hasMatrix) {
    mat4_mul(m, node->transform.matrix);
  } else {
    float* T = node->transform.translation;
    float* R = node->transform.rotation;
    float* S = node->transform.scale;
    mat4_translate(m, T[0], T[1], T[2]);
    mat4_rotateQuat(m, R);
    mat4_scale(m, S[0], S[1], S[2]);
  }

  if (node->mesh != ~0u) {
    ModelMesh* mesh = &model->meshes[node->mesh];

    for (uint32_t i = 0; i < mesh->primitiveCount; i++) {
      ModelPrimitive* primitive = &mesh->primitives[i];

      float xmin = primitive->bounds[0], xmax = primitive->bounds[1];
      float ymin = primitive->bounds[2], ymax = primitive->bounds[3];
      float zmin = primitive->bounds[4], zmax = primitive->bounds[5];

      float corners[8][3] = {
        { xmin, ymin, zmin },
        { xmin, ymin, zmax },
        { xmin, ymax, zmin },
        { xmin, ymax, zmax },
        { xmax, ymin, zmin },
        { xmax, ymin, zmax },
        { xmax, ymax, zmin },
        { xmax, ymax, zmax }
      };

      for (uint32_t j = 0; j < 8; j++) {
        mat4_mulPoint(m, corners[j]);
        vec3_init(points + 3 * (*pointIndex)++, corners[j]);
      }
    }
  }

  for (uint32_t i = node->child; i != ~0u; i = model->nodes[i].sibling) {
    boundingSphereHelper(model, i, pointIndex, points, m);
  }
}

void lovrModelDataGetBoundingSphere(ModelData* model, float sphere[4]) {
  if (model->boundingSphere[3] == 0.f) {
    uint32_t totalPrimitiveCount = 0;

    for (uint32_t i = 0; i < model->nodeCount; i++) {
      if (model->nodes[i].mesh != ~0u) {
        totalPrimitiveCount += model->meshes[model->nodes[i].mesh].primitiveCount;
      }
    }

    uint32_t pointCount = totalPrimitiveCount * 8;
    float* points = lovrMalloc(pointCount * 3 * sizeof(float));

    uint32_t pointIndex = 0;
    boundingSphereHelper(model, model->rootNode, &pointIndex, points, (float[16]) MAT4_IDENTITY);

    // Find point furthest away from first point

    float max = 0.f;
    float* a = NULL;
    for (uint32_t i = 1; i < pointCount; i++) {
      float d2 = vec3_distance2(&points[3 * i], &points[0]);
      if (d2 > max) {
        a = &points[3 * i];
        max = d2;
      }
    }

    // Find point furthest away from that point

    max = 0.f;
    float* b = NULL;
    for (uint32_t i = 0; i < pointCount; i++) {
      float d2 = vec3_distance2(&points[3 * i], a);
      if (d2 > max) {
        b = &points[3 * i];
        max = d2;
      }
    }

    // Create and refine sphere

    float dx = a[0] - b[0];
    float dy = a[1] - b[1];
    float dz = a[2] - b[2];
    float x = (a[0] + b[0]) / 2.f;
    float y = (a[1] + b[1]) / 2.f;
    float z = (a[2] + b[2]) / 2.f;
    float r = sqrtf(dx * dx + dy * dy + dz * dz) / 2.f;
    float r2 = r * r;

    for (uint32_t i = 0; i < pointCount; i++) {
      float dx = points[3 * i + 0] - x;
      float dy = points[3 * i + 1] - y;
      float dz = points[3 * i + 2] - z;
      float d2 = dx * dx + dy * dy + dz * dz;
      if (d2 > r2) {
        r = sqrtf(d2);
        r2 = r * r;
      }
    }

    model->boundingSphere[0] = x;
    model->boundingSphere[1] = y;
    model->boundingSphere[2] = z;
    model->boundingSphere[3] = r;
    lovrFree(points);
  }

  memcpy(sphere, model->boundingSphere, sizeof(model->boundingSphere));
}

static void countVertices(ModelData* model, uint32_t nodeIndex, uint32_t* vertexCount, uint32_t* indexCount) {
  ModelNode* node = &model->nodes[nodeIndex];

  if (node->mesh != ~0u) {
    ModelMesh* mesh = &model->meshes[node->mesh];
    for (uint32_t i = 0; i < mesh->primitiveCount; i++) {
      ModelPrimitive* primitive = &mesh->primitives[i];

      if (primitive->mode != DRAW_TRIANGLE_LIST) {
        continue;
      }

      model->triangleVertexCount += primitive->vertexCount;
      model->triangleIndexCount += primitive->indexCount > 0 ? primitive->count : primitive->vertexCount;
    }
  }

  for (uint32_t i = node->child; i != ~0u; i = model->nodes[i].sibling) {
    countVertices(model, i, vertexCount, indexCount);
  }
}

static void collectVertices(ModelData* model, uint32_t nodeIndex, float** vertices, uint32_t** indices, uint32_t* baseIndex, float* parentTransform) {
  ModelNode* node = &model->nodes[nodeIndex];

  float m[16];
  mat4_init(m, parentTransform);

  if (node->hasMatrix) {
    mat4_mul(m, node->transform.matrix);
  } else {
    float* T = node->transform.translation;
    float* R = node->transform.rotation;
    float* S = node->transform.scale;
    mat4_translate(m, T[0], T[1], T[2]);
    mat4_rotateQuat(m, R);
    mat4_scale(m, S[0], S[1], S[2]);
  }

  uint32_t nodeBase = *baseIndex;

  if (node->mesh != ~0u) {
    ModelMesh* mesh = &model->meshes[node->mesh];
    ModelVertex* vertex = mesh->vertices;
    void* index = mesh->indices;

    for (uint32_t i = 0; i < mesh->primitiveCount; i++) {
      ModelPrimitive* primitive = &mesh->primitives[i];

      if (primitive->mode != DRAW_TRIANGLE_LIST) {
        continue;
      }

      uint32_t base = nodeBase;

      if (base == *baseIndex) {
        for (uint32_t j = 0; j < primitive->vertexCount; j++) {
          float v[3] = { vertex->position.x, vertex->position.y, vertex->position.z };
          vec3_init(*vertices, mat4_mulPoint(m, v));
          *vertices += 3;
          vertex++;
        }

        *baseIndex += primitive->vertexCount;
      }

      if (primitive->indexCount > 0) {
        if (model->indexSize == 4) {
          for (uint32_t j = 0; j < primitive->indexCount; j++) {
            **indices = *(uint32_t*) index + base;
            *indices += 1;
            index = (char*) index + 4;
          }
        } else if (model->indexSize == 2) {
          for (uint32_t j = 0; j < primitive->indexCount; j++) {
            **indices = (uint32_t) *(uint16_t*) index + base;
            *indices += 1;
            index = (char*) index + 2;
          }
        } else {
          lovrUnreachable();
        }
      } else {
        for (uint32_t j = 0; j < primitive->vertexCount; j++) {
          **indices = j + base;
          *indices += 1;
        }
      }
    }
  }

  for (uint32_t i = node->child; i != ~0u; i = model->nodes[i].sibling) {
    collectVertices(model, i, vertices, indices, baseIndex, m);
  }
}

void lovrModelDataGetTriangles(ModelData* model, float** vertices, uint32_t** indices, uint32_t* vertexCount, uint32_t* indexCount) {
  if (model->triangleVertexCount == 0) {
    countVertices(model, model->rootNode, vertexCount, indexCount);
  }

  if (vertices && !model->vertices) {
    uint32_t* tempIndices;
    uint32_t baseIndex = 0;
    model->vertices = lovrMalloc(model->triangleVertexCount * 3 * sizeof(float));
    model->indices = lovrMalloc(model->triangleIndexCount * sizeof(uint32_t));
    *vertices = model->triangleVertices;
    tempIndices = model->triangleIndices;
    collectVertices(model, model->rootNode, vertices, &tempIndices, &baseIndex, (float[16]) MAT4_IDENTITY);
  }

  if (vertexCount) *vertexCount = model->triangleVertexCount;
  if (indexCount) *indexCount = model->triangleIndexCount;

  if (vertices) *vertices = model->triangleVertices;
  if (indices) *indices = model->triangleIndices;
}
