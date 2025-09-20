#include "data/modelData.h"
#include "data/blob.h"
#include "data/image.h"
#include "core/maf.h"
#include "util.h"
#include <stdlib.h>
#include <string.h>
#include <float.h>

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

  lovrModelDataFinalize(model);

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
  size_t sizes[17];
  size_t alignment = 8;
  totalSize += sizes[0] = ALIGN(model->meshCount * sizeof(ModelMesh), alignment);
  totalSize += sizes[1] = ALIGN(model->imageCount * sizeof(Image*), alignment);
  totalSize += sizes[2] = ALIGN(model->materialCount * sizeof(ModelMaterial), alignment);
  totalSize += sizes[3] = ALIGN(model->animationCount * sizeof(ModelAnimation), alignment);
  totalSize += sizes[4] = ALIGN(model->skinCount * sizeof(ModelSkin), alignment);
  totalSize += sizes[5] = ALIGN(model->nodeCount * sizeof(ModelNode), alignment);
  totalSize += sizes[6] = ALIGN(model->partCount * sizeof(ModelPart), alignment);
  totalSize += sizes[7] = ALIGN(model->blendShapeCount * sizeof(ModelBlendShape), alignment);
  totalSize += sizes[8] = ALIGN(model->channelCount * sizeof(ModelAnimationChannel), alignment);
  totalSize += sizes[9] = ALIGN(model->keyframeDataCount * sizeof(float), alignment);
  totalSize += sizes[10] = ALIGN(model->jointCount * 16 * sizeof(float), alignment);
  totalSize += sizes[11] = ALIGN(model->jointCount * sizeof(uint32_t), alignment);
  totalSize += sizes[12] = ALIGN(model->charCount * sizeof(char), alignment);
  totalSize += sizes[13] = ALIGN(sizeof(map_t), alignment);
  totalSize += sizes[14] = ALIGN(sizeof(map_t), alignment);
  totalSize += sizes[15] = ALIGN(sizeof(map_t), alignment);
  totalSize += sizes[16] = ALIGN(sizeof(map_t), alignment);

  size_t offset = 0;
  char* p = model->data = lovrCalloc(totalSize);
  model->meshes = (ModelMesh*) (p + offset), offset += sizes[0];
  model->images = (Image**) (p + offset), offset += sizes[1];
  model->materials = (ModelMaterial*) (p + offset), offset += sizes[2];
  model->animations = (ModelAnimation*) (p + offset), offset += sizes[3];
  model->skins = (ModelSkin*) (p + offset), offset += sizes[4];
  model->nodes = (ModelNode*) (p + offset), offset += sizes[5];
  model->parts = (ModelPart*) (p + offset), offset += sizes[6];
  model->blendShapes = (ModelBlendShape*) (p + offset), offset += sizes[7];
  model->channels = (ModelAnimationChannel*) (p + offset), offset += sizes[8];
  model->keyframeData = (float*) (p + offset), offset += sizes[9];
  model->inverseBindMatrices = (float*) (p + offset), offset += sizes[10];
  model->joints = (uint32_t*) (p + offset), offset += sizes[11];
  model->chars = (char*) (p + offset), offset += sizes[12];
  model->blendShapeMap = (map_t*) (p + offset), offset += sizes[13];
  model->animationMap = (map_t*) (p + offset), offset += sizes[14];
  model->materialMap = (map_t*) (p + offset), offset += sizes[15];
  model->nodeMap = (map_t*) (p + offset), offset += sizes[16];

  model->vertices = model->vertexCount > 0 ? lovrMalloc(model->vertexCount * sizeof(ModelVertex)) : NULL;
  model->indices = model->indexCount > 0 ? lovrMalloc(model->indexCount * model->indexSize) : NULL;
  model->skinData = model->skinnedVertexCount > 0 ? lovrMalloc(model->skinnedVertexCount * sizeof(SkinData)) : NULL;
  model->blendData = model->blendedVertexCount > 0 ? lovrMalloc(model->blendedVertexCount * sizeof(BlendData)) : NULL;

  map_init(model->blendShapeMap, model->blendShapeCount);
  map_init(model->animationMap, model->animationCount);
  map_init(model->materialMap, model->materialCount);
  map_init(model->nodeMap, model->nodeCount);

  for (uint32_t i = 0; i < model->meshCount; i++) {
    model->meshes[i].vertexOffset = ~0u;
    model->meshes[i].indexOffset = ~0u;
    model->meshes[i].skinDataOffset = ~0u;
    model->meshes[i].blendDataOffset = ~0u;
  }

  for (uint32_t i = 0; i < model->partCount; i++) {
    model->parts[i].mode = DRAW_TRIANGLE_LIST;
    model->parts[i].material = ~0u;
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
    ModelNode* node = model->nodes;
    for (uint32_t j = 0; j < model->nodeCount; j++, node++) {
      if (node->mesh == i) {
        if (skin == ~0u) {
          skin = node->skin;
        } else {
          lovrAssert(node->skin == skin, "Model has mesh used with multiple different skins, which is not currently supported");
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

    for (uint32_t i = 0; i < mesh->partCount; i++) {
      ModelPart* part = &mesh->parts[i];

      float xmin = part->bounds[0], xmax = part->bounds[1];
      float ymin = part->bounds[2], ymax = part->bounds[3];
      float zmin = part->bounds[4], zmax = part->bounds[5];

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

void lovrModelDataGetMeshBoundingBox(ModelData* model, uint32_t index, float box[6]) {
  ModelMesh* mesh = &model->meshes[index];
  memcpy(box, mesh->parts[0].bounds, 6 * sizeof(float));
  for (uint32_t i = 1; i < mesh->partCount; i++) {
    box[0] = MIN(box[0], mesh->parts[i].bounds[0]);
    box[1] = MAX(box[1], mesh->parts[i].bounds[1]);
    box[2] = MIN(box[2], mesh->parts[i].bounds[2]);
    box[3] = MAX(box[3], mesh->parts[i].bounds[3]);
    box[4] = MIN(box[4], mesh->parts[i].bounds[4]);
    box[5] = MAX(box[5], mesh->parts[i].bounds[5]);
  }
}

static void gatherBoundingBoxCorners(ModelData* model, uint32_t nodeIndex, uint32_t* pointIndex, float* points, float* parentTransform) {
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
    ModelPart* part = mesh->parts;

    for (uint32_t i = 0; i < mesh->partCount; i++, part++) {
      float xmin = part->bounds[0], xmax = part->bounds[1];
      float ymin = part->bounds[2], ymax = part->bounds[3];
      float zmin = part->bounds[4], zmax = part->bounds[5];

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
    gatherBoundingBoxCorners(model, i, pointIndex, points, m);
  }
}

static void computeBoundingSphere(float* points, uint32_t pointCount, size_t stride, float sphere[4]) {

  // Find point furthest away from first point

  float max = 0.f;
  float* a = NULL;
  for (uint32_t i = 1; i < pointCount; i++) {
    float d2 = vec3_distance2(&points[i * stride], &points[0]);
    if (d2 > max) {
      a = &points[i * stride];
      max = d2;
    }
  }

  // Find point furthest away from that point

  max = 0.f;
  float* b = NULL;
  for (uint32_t i = 0; i < pointCount; i++) {
    float d2 = vec3_distance2(&points[i * stride], a);
    if (d2 > max) {
      b = &points[i * stride];
      max = d2;
    }
  }

  // Create and refine sphere

  float dx = a[0] - b[0];
  float dy = a[1] - b[1];
  float dz = a[2] - b[2];
  float cx = (a[0] + b[0]) / 2.f;
  float cy = (a[1] + b[1]) / 2.f;
  float cz = (a[2] + b[2]) / 2.f;
  float r2 = (dx * dx + dy * dy + dz * dz) / 4.f; // Initial radius is half the distance between points

  for (uint32_t i = 0; i < pointCount; i++) {
    float dx = points[i * stride + 0] - cx;
    float dy = points[i * stride + 1] - cy;
    float dz = points[i * stride + 2] - cz;
    float d2 = dx * dx + dy * dy + dz * dz;
    if (d2 > r2) {
      r2 = d2; // beep boop
    }
  }

  sphere[0] = cx;
  sphere[1] = cy;
  sphere[2] = cz;
  sphere[3] = sqrtf(r2);
}

void lovrModelDataGetBoundingSphere(ModelData* model, float sphere[4]) {
  if (model->boundingSphere[3] == 0.f) {
    uint32_t totalPartCount = 0;

    for (uint32_t i = 0; i < model->nodeCount; i++) {
      if (model->nodes[i].mesh != ~0u) {
        totalPartCount += model->meshes[model->nodes[i].mesh].partCount;
      }
    }

    uint32_t pointCount = totalPartCount * 8;
    float* points = lovrMalloc(pointCount * 3 * sizeof(float));

    uint32_t pointIndex = 0;
    gatherBoundingBoxCorners(model, model->rootNode, &pointIndex, points, (float[16]) MAT4_IDENTITY);
    computeBoundingSphere(points, pointCount, 3, model->boundingSphere);
    lovrFree(points);
  }

  memcpy(sphere, model->boundingSphere, sizeof(model->boundingSphere));
}

void lovrModelDataGetMeshBoundingSphere(ModelData* model, uint32_t index, uint32_t part, float sphere[4]) {
  ModelMesh* mesh = &model->meshes[index];
  uint32_t nextVertexOffset = part == mesh->partCount - 1 ? mesh->vertexOffset + mesh->vertexCount : mesh->parts[part + 1].baseVertex;
  uint32_t start = part == ~0u ? mesh->vertexOffset : mesh->parts[part].baseVertex;
  uint32_t count = part == ~0u ? mesh->vertexCount : nextVertexOffset - start;
  float* vertex = &model->vertices[start].position.x;
  computeBoundingSphere(vertex, count, sizeof(ModelVertex) / sizeof(float), sphere);
}

static void countVertices(ModelData* model, uint32_t nodeIndex, uint32_t* vertexCount, uint32_t* indexCount) {
  ModelNode* node = &model->nodes[nodeIndex];

  if (node->mesh != ~0u) {
    ModelMesh* mesh = &model->meshes[node->mesh];
    ModelPart* part = mesh->parts;

    model->triangleVertexCount += mesh->vertexCount;

    for (uint32_t i = 0; i < mesh->partCount; i++, part++) {
      if (part->mode == DRAW_TRIANGLE_LIST) {
        model->triangleIndexCount += part->count;
      }
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

  if (node->mesh != ~0u) {
    ModelMesh* mesh = &model->meshes[node->mesh];
    ModelVertex* vertex = model->vertices + mesh->vertexOffset;
    ModelPart* part = mesh->parts;

    for (uint32_t i = 0; i < mesh->vertexCount; i++, vertex++) {
      float v[3] = { vertex->position.x, vertex->position.y, vertex->position.z };
      vec3_init(*vertices, mat4_mulPoint(m, v));
      *vertices += 3;
    }

    for (uint32_t i = 0; i < mesh->partCount; i++, part++) {
      if (part->mode != DRAW_TRIANGLE_LIST) {
        continue;
      }

      if (mesh->indexCount > 0) {
        if (model->indexSize == 4) {
          uint32_t* indexData = (uint32_t*) model->indices + part->start;
          for (uint32_t j = 0; j < part->count; j++) {
            **indices = indexData[j] + *baseIndex;
            *indices += 1;
          }
        } else if (model->indexSize == 2) {
          uint16_t* indexData = (uint16_t*) model->indices + part->start;
          for (uint32_t j = 0; j < part->count; j++) {
            **indices = (uint32_t) indexData[j] + *baseIndex;
            *indices += 1;
          }
        } else {
          lovrUnreachable();
        }
      } else {
        for (uint32_t j = 0; j < part->count; j++) {
          **indices = *baseIndex + j;
          *indices += 1;
        }
      }
    }

    *baseIndex += mesh->vertexCount;
  }

  for (uint32_t i = node->child; i != ~0u; i = model->nodes[i].sibling) {
    collectVertices(model, i, vertices, indices, baseIndex, m);
  }
}

void lovrModelDataGetTriangles(ModelData* model, float** vertices, uint32_t** indices, uint32_t* vertexCount, uint32_t* indexCount) {
  if (model->triangleVertexCount == 0) {
    countVertices(model, model->rootNode, vertexCount, indexCount);
  }

  if (vertices && !model->triangleVertices) {
    uint32_t* tempIndices;
    uint32_t baseIndex = 0;
    model->triangleVertices = lovrMalloc(model->triangleVertexCount * 3 * sizeof(float));
    model->triangleIndices = lovrMalloc(model->triangleIndexCount * sizeof(uint32_t));
    *vertices = model->triangleVertices;
    tempIndices = model->triangleIndices;
    collectVertices(model, model->rootNode, vertices, &tempIndices, &baseIndex, (float[16]) MAT4_IDENTITY);
  }

  if (vertexCount) *vertexCount = model->triangleVertexCount;
  if (indexCount) *indexCount = model->triangleIndexCount;

  if (vertices) *vertices = model->triangleVertices;
  if (indices) *indices = model->triangleIndices;
}

uint32_t lovrModelDataNextNodeWithMesh(ModelData* model, uint32_t node) {
  while (++node < model->nodeCount) {
    if (model->nodes[node].mesh != ~0u) {
      return node;
    }
  }

  return ~0u;
}
