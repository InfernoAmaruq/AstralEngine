#include "api.h"
#include "data/modelData.h"
#include "core/maf.h"
#include "util.h"
#include <stdlib.h>

uint32_t luax_checkanimationindex(lua_State* L, int index, ModelData* model) {
  switch (lua_type(L, index)) {
    case LUA_TNUMBER: {
      uint32_t animation = luax_checku32(L, index) - 1;
      luax_check(L, animation < model->animationCount, "Invalid animation index '%d'", animation + 1);
      return animation;
    }
    case LUA_TSTRING: {
      size_t length;
      const char* name = lua_tolstring(L, index, &length);
      uint64_t hash = hash64(name, length);
      uint64_t entry = map_get(model->animationMap, hash);
      luax_check(L, entry != MAP_NIL, "Model has no animation named '%s'", name);
      return (uint32_t) entry;
    }
    default: return luax_typeerror(L, index, "number or string"), ~0u;
  }
}

uint32_t luax_checkmaterialindex(lua_State* L, int index, ModelData* model) {
  switch (lua_type(L, index)) {
    case LUA_TNUMBER: {
      uint32_t material = luax_checku32(L, index) - 1;
      luax_check(L, material < model->materialCount, "Invalid material index '%d'", material + 1);
      return material;
    }
    case LUA_TSTRING: {
      size_t length;
      const char* name = lua_tolstring(L, index, &length);
      uint64_t hash = hash64(name, length);
      uint64_t entry = map_get(model->materialMap, hash);
      luax_check(L, entry != MAP_NIL, "Model has no material named '%s'", name);
      return (uint32_t) entry;
    }
    default: return luax_typeerror(L, index, "number or string"), ~0u;
  }
}

uint32_t luax_checknodeindex(lua_State* L, int index, ModelData* model) {
  switch (lua_type(L, index)) {
    case LUA_TNUMBER: {
      uint32_t node = luax_checku32(L, index) - 1;
      luax_check(L, node < model->nodeCount, "Invalid node index '%d'", node + 1);
      return node;
    }
    case LUA_TSTRING: {
      size_t length;
      const char* name = lua_tolstring(L, index, &length);
      uint64_t hash = hash64(name, length);
      uint64_t entry = map_get(model->nodeMap, hash);
      luax_check(L, entry != MAP_NIL, "Model has no node named '%s'", name);
      return (uint32_t) entry;
    }
    default: return luax_typeerror(L, index, "number or string"), ~0u;
  }
}

uint32_t luax_checkmeshindex(lua_State* L, int index, ModelData* model) {
  uint32_t mesh = luax_checku32(L, index) - 1;
  luax_check(L, mesh < model->meshCount, "Invalid mesh index '%d'", mesh + 1);
  return 1;
}

ModelPart* luax_checkmeshpart(lua_State* L, int index, ModelData* model) {
  uint32_t mesh = luax_checkmeshindex(L, index, model);
  uint32_t part = luax_optu32(L, index + 1, 1) - 1;
  luax_check(L, part < model->meshes[mesh].partCount, "Invalid part index '%d'", part + 1);
  return &model->meshes[mesh].parts[part];
}

static int l_lovrModelDataGetMetadata(lua_State* L) {
  ModelData* model = luax_checktype(L, 1, ModelData);

  if (!model->metadata || model->metadataSize == 0) {
    lua_pushnil(L);
  } else {
    lua_pushlstring(L, model->metadata, model->metadataSize);
  }

  return 1;
}

static int l_lovrModelDataGetRootNode(lua_State* L) {
  ModelData* model = luax_checktype(L, 1, ModelData);
  lua_pushinteger(L, model->rootNode + 1);
  return 1;
}

static int l_lovrModelDataGetNodeCount(lua_State* L) {
  ModelData* model = luax_checktype(L, 1, ModelData);
  lua_pushinteger(L, model->nodeCount);
  return 1;
}

static int l_lovrModelDataGetNodeName(lua_State* L) {
  ModelData* model = luax_checktype(L, 1, ModelData);
  uint32_t index = luax_checku32(L, 2) - 1;
  luax_check(L, index < model->nodeCount, "Invalid node index '%d'", index + 1);
  lua_pushstring(L, model->nodes[index].name);
  return 1;
}

static int l_lovrModelDataGetNodeChild(lua_State* L) {
  ModelData* model = luax_checktype(L, 1, ModelData);
  ModelNode* node = &model->nodes[luax_checknodeindex(L, 2, model)];
  if (node->child != ~0u) {
    lua_pushinteger(L, node->child + 1);
  } else {
    lua_pushnil(L);
  }
  return 1;
}

static int l_lovrModelDataGetNodeChildren(lua_State* L) {
  ModelData* model = luax_checktype(L, 1, ModelData);
  ModelNode* node = &model->nodes[luax_checknodeindex(L, 2, model)];
  lua_newtable(L);
  for (uint32_t i = node->child; i != ~0u; i = model->nodes[i].sibling) {
    lua_pushinteger(L, i + 1);
    lua_rawseti(L, -2, i + 1);
  }
  return 1;
}

static int l_lovrModelDataGetNodeSibling(lua_State* L) {
  ModelData* model = luax_checktype(L, 1, ModelData);
  ModelNode* node = &model->nodes[luax_checknodeindex(L, 2, model)];
  if (node->sibling != ~0u) {
    lua_pushinteger(L, node->sibling + 1);
  } else {
    lua_pushnil(L);
  }
  return 1;
}

static int l_lovrModelDataGetNodeParent(lua_State* L) {
  ModelData* model = luax_checktype(L, 1, ModelData);
  ModelNode* node = &model->nodes[luax_checknodeindex(L, 2, model)];
  if (node->parent != ~0u) {
    lua_pushinteger(L, node->parent + 1);
  } else {
    lua_pushnil(L);
  }
  return 1;
}

static int l_lovrModelDataGetNodePosition(lua_State* L) {
  ModelData* model = luax_checktype(L, 1, ModelData);
  ModelNode* node = &model->nodes[luax_checknodeindex(L, 2, model)];
  if (node->hasMatrix) {
    float position[3];
    mat4_getPosition(node->transform.matrix, position);
    lua_pushnumber(L, position[0]);
    lua_pushnumber(L, position[1]);
    lua_pushnumber(L, position[2]);
    return 3;
  } else {
    lua_pushnumber(L, node->transform.translation[0]);
    lua_pushnumber(L, node->transform.translation[1]);
    lua_pushnumber(L, node->transform.translation[2]);
    return 3;
  }
}

static int l_lovrModelDataGetNodeOrientation(lua_State* L) {
  ModelData* model = luax_checktype(L, 1, ModelData);
  ModelNode* node = &model->nodes[luax_checknodeindex(L, 2, model)];
  float angle, ax, ay, az;
  if (node->hasMatrix) {
    mat4_getAngleAxis(node->transform.matrix, &angle, &ax, &ay, &az);
  } else {
    quat_getAngleAxis(node->transform.rotation, &angle, &ax, &ay, &az);
  }
  lua_pushnumber(L, angle);
  lua_pushnumber(L, ax);
  lua_pushnumber(L, ay);
  lua_pushnumber(L, az);
  return 4;
}

static int l_lovrModelDataGetNodeScale(lua_State* L) {
  ModelData* model = luax_checktype(L, 1, ModelData);
  ModelNode* node = &model->nodes[luax_checknodeindex(L, 2, model)];
  if (node->hasMatrix) {
    float scale[3];
    mat4_getScale(node->transform.matrix, scale);
    lua_pushnumber(L, scale[0]);
    lua_pushnumber(L, scale[1]);
    lua_pushnumber(L, scale[2]);
  } else {
    lua_pushnumber(L, node->transform.scale[0]);
    lua_pushnumber(L, node->transform.scale[1]);
    lua_pushnumber(L, node->transform.scale[2]);
  }
  return 3;
}

static int l_lovrModelDataGetNodePose(lua_State* L) {
  ModelData* model = luax_checktype(L, 1, ModelData);
  ModelNode* node = &model->nodes[luax_checknodeindex(L, 2, model)];
  if (node->hasMatrix) {
    float position[3], angle, ax, ay, az;
    mat4_getPosition(node->transform.matrix, position);
    mat4_getAngleAxis(node->transform.matrix, &angle, &ax, &ay, &az);
    lua_pushnumber(L, position[0]);
    lua_pushnumber(L, position[1]);
    lua_pushnumber(L, position[2]);
    lua_pushnumber(L, angle);
    lua_pushnumber(L, ax);
    lua_pushnumber(L, ay);
    lua_pushnumber(L, az);
  } else {
    float angle, ax, ay, az;
    quat_getAngleAxis(node->transform.rotation, &angle, &ax, &ay, &az);
    lua_pushnumber(L, node->transform.translation[0]);
    lua_pushnumber(L, node->transform.translation[1]);
    lua_pushnumber(L, node->transform.translation[2]);
    lua_pushnumber(L, angle);
    lua_pushnumber(L, ax);
    lua_pushnumber(L, ay);
    lua_pushnumber(L, az);
  }
  return 7;
}

static int l_lovrModelDataGetNodeTransform(lua_State* L) {
  ModelData* model = luax_checktype(L, 1, ModelData);
  ModelNode* node = &model->nodes[luax_checknodeindex(L, 2, model)];
  if (node->hasMatrix) {
    float position[3], scale[4], angle, ax, ay, az;
    mat4_getPosition(node->transform.matrix, position);
    mat4_getScale(node->transform.matrix, scale);
    mat4_getAngleAxis(node->transform.matrix, &angle, &ax, &ay, &az);
    lua_pushnumber(L, position[0]);
    lua_pushnumber(L, position[1]);
    lua_pushnumber(L, position[2]);
    lua_pushnumber(L, scale[0]);
    lua_pushnumber(L, scale[1]);
    lua_pushnumber(L, scale[2]);
    lua_pushnumber(L, angle);
    lua_pushnumber(L, ax);
    lua_pushnumber(L, ay);
    lua_pushnumber(L, az);
  } else {
    float angle, ax, ay, az;
    quat_getAngleAxis(node->transform.rotation, &angle, &ax, &ay, &az);
    lua_pushnumber(L, node->transform.translation[0]);
    lua_pushnumber(L, node->transform.translation[1]);
    lua_pushnumber(L, node->transform.translation[2]);
    lua_pushnumber(L, node->transform.scale[0]);
    lua_pushnumber(L, node->transform.scale[1]);
    lua_pushnumber(L, node->transform.scale[2]);
    lua_pushnumber(L, angle);
    lua_pushnumber(L, ax);
    lua_pushnumber(L, ay);
    lua_pushnumber(L, az);
  }
  return 10;
}

static int l_lovrModelDataGetNodeMesh(lua_State* L) {
  ModelData* model = luax_checktype(L, 1, ModelData);
  ModelNode* node = &model->nodes[luax_checknodeindex(L, 2, model)];
  if (node->mesh == ~0u) {
    lua_pushnil(L);
  } else {
    lua_pushinteger(L, node->mesh + 1);
  }
  return 1;
}

static int l_lovrModelDataGetNodeSkin(lua_State* L) {
  ModelData* model = luax_checktype(L, 1, ModelData);
  ModelNode* node = &model->nodes[luax_checknodeindex(L, 2, model)];
  if (node->skin == ~0u) {
    lua_pushnil(L);
  } else {
    lua_pushinteger(L, node->skin + 1);
  }
  return 1;
}

static int l_lovrModelDataGetMeshCount(lua_State* L) {
  ModelData* model = luax_checktype(L, 1, ModelData);
  lua_pushinteger(L, model->meshCount);
  return 1;
}

static int l_lovrModelDataGetMeshPartCount(lua_State* L) {
  ModelData* model = luax_checktype(L, 1, ModelData);
  uint32_t mesh = luax_checkmeshindex(L, 2, model);
  lua_pushinteger(L, model->meshes[mesh].partCount);
  return 1;
}

static int l_lovrModelDataGetMeshDrawMode(lua_State* L) {
  ModelData* model = luax_checktype(L,  1, ModelData);
  ModelPart* part = luax_checkmeshpart(L, 2, model);
  luax_pushenum(L, ModelDrawMode, part->mode);
  return 1;
}

static int l_lovrModelDataGetMeshDrawRange(lua_State* L) {
  ModelData* model = luax_checktype(L,  1, ModelData);
  ModelPart* part = luax_checkmeshpart(L, 2, model);
  lua_pushinteger(L, part->start + 1);
  lua_pushinteger(L, part->count);
  return 2;
}

static int l_lovrModelDataGetMeshBaseVertex(lua_State* L) {
  ModelData* model = luax_checktype(L,  1, ModelData);
  ModelPart* part = luax_checkmeshpart(L, 2, model);
  lua_pushinteger(L, part->baseVertex);
  return 1;
}

static int l_lovrModelDataGetMeshMaterial(lua_State* L) {
  ModelData* model = luax_checktype(L,  1, ModelData);
  ModelPart* part = luax_checkmeshpart(L, 2, model);
  lua_pushinteger(L, part->material + 1);
  return 1;
}

static int l_lovrModelDataGetTriangles(lua_State* L) {
  ModelData* model = luax_checktype(L, 1, ModelData);

  if (lua_isnoneornil(L, 2)) {
    float* vertices = NULL;
    uint32_t* indices = NULL;
    uint32_t vertexCount = 0;
    uint32_t indexCount = 0;
    lovrModelDataGetTriangles(model, &vertices, &indices, &vertexCount, &indexCount);

    lua_createtable(L, vertexCount * 3, 0);
    for (uint32_t i = 0; i < vertexCount * 3; i++) {
      lua_pushnumber(L, vertices[i]);
      lua_rawseti(L, -2, i + 1);
    }

    lua_createtable(L, indexCount, 0);
    for (uint32_t i = 0; i < indexCount; i++) {
      lua_pushinteger(L, indices[i] + 1);
      lua_rawseti(L, -2, i + 1);
    }
  } else {
    uint32_t meshIndex = luax_checku32(L, 2) - 1;
    luax_check(L, meshIndex < model->meshCount, "Invalid mesh index '%d'", meshIndex + 1);

    ModelMesh* mesh = &model->meshes[meshIndex];
    ModelVertex* vertex = model->vertices + mesh->vertexOffset;

    lua_createtable(L, mesh->vertexCount, 0);
    for (uint32_t i = 0; i < mesh->vertexCount; i++, vertex++) {
      lua_pushnumber(L, vertex->position.x);
      lua_rawseti(L, -2, 3 * i + 1);

      lua_pushnumber(L, vertex->position.y);
      lua_rawseti(L, -2, 3 * i + 2);

      lua_pushnumber(L, vertex->position.z);
      lua_rawseti(L, -2, 3 * i + 3);
    }

    if (mesh->indexCount > 0) {
      void* indices = model->indices;
      uint32_t base = mesh->parts->baseVertex;
      lua_createtable(L, mesh->indexCount, 0);

      for (uint32_t i = 0; i < mesh->indexCount; i++) {
        uint32_t index = model->indexSize == 4 ? ((uint32_t*) indices)[i] : ((uint16_t*) indices)[i];
        lua_pushinteger(L, index - base + 1);
        lua_rawseti(L, -2, i + 1);
      }
    } else {
      for (uint32_t i = 0; i < mesh->vertexCount; i++) {
        lua_pushinteger(L, i + 1);
        lua_rawseti(L, -2, i + 1);
      }
    }
  }

  return 2;
}

static int l_lovrModelDataGetTriangleCount(lua_State* L) {
  ModelData* model = luax_checktype(L, 1, ModelData);

  if (lua_isnoneornil(L, 2)) {
    uint32_t vertexCount, indexCount;
    lovrModelDataGetTriangles(model, NULL, NULL, &vertexCount, &indexCount);
    lua_pushinteger(L, indexCount / 3);
  } else {
    uint32_t meshIndex = luax_checku32(L, 2) - 1;
    luax_check(L, meshIndex < model->meshCount, "Invalid mesh index '%d'", meshIndex + 1);
    ModelMesh* mesh = &model->meshes[meshIndex];
    uint32_t count = 0;

    for (uint32_t i = 0; i < mesh->partCount; i++) {
      if (mesh->parts[i].mode == DRAW_TRIANGLE_LIST) {
        count += mesh->parts[i].count / 3;
      }
    }

    lua_pushinteger(L, count);
  }

  return 1;
}

static int l_lovrModelDataGetVertexCount(lua_State* L) {
  ModelData* model = luax_checktype(L, 1, ModelData);
  uint32_t vertexCount, indexCount;
  lovrModelDataGetTriangles(model, NULL, NULL, &vertexCount, &indexCount);
  lua_pushinteger(L, vertexCount);
  return 1;
}

static void luax_checkboundingbox(lua_State* L, int index, ModelData* model, float bounds[6]) {
  if (lua_type(L, index) == LUA_TNONE) {
    lovrModelDataGetBoundingBox(model, bounds);
    return;
  }

  uint32_t mesh = luax_checku32(L, index) - 1;
  luax_check(L, mesh < model->meshCount, "Invalid mesh index '%d'", mesh + 1);

  if (lua_type(L, index + 1) == LUA_TNONE) {
    lovrModelDataGetMeshBoundingBox(model, mesh, bounds);
    return;
  }

  uint32_t part = luax_checku32(L, index + 1) - 1;
  luax_check(L, part < model->meshes[mesh].partCount, "Invalid part index '%d'", part + 1);
  memcpy(bounds, model->meshes[mesh].parts[part].bounds, 6 * sizeof(float));
}

static int l_lovrModelDataGetWidth(lua_State* L) {
  ModelData* model = luax_checktype(L, 1, ModelData);
  float bounds[6];
  luax_checkboundingbox(L, 2, model, bounds);
  lua_pushnumber(L, bounds[1] - bounds[0]);
  return 1;
}

static int l_lovrModelDataGetHeight(lua_State* L) {
  ModelData* model = luax_checktype(L, 1, ModelData);
  float bounds[6];
  luax_checkboundingbox(L, 2, model, bounds);
  lua_pushnumber(L, bounds[3] - bounds[2]);
  return 1;
}

static int l_lovrModelDataGetDepth(lua_State* L) {
  ModelData* model = luax_checktype(L, 1, ModelData);
  float bounds[6];
  luax_checkboundingbox(L, 2, model, bounds);
  lua_pushnumber(L, bounds[5] - bounds[4]);
  return 1;
}

static int l_lovrModelDataGetDimensions(lua_State* L) {
  ModelData* model = luax_checktype(L, 1, ModelData);
  float bounds[6];
  luax_checkboundingbox(L, 2, model, bounds);
  lua_pushnumber(L, bounds[1] - bounds[0]);
  lua_pushnumber(L, bounds[3] - bounds[2]);
  lua_pushnumber(L, bounds[5] - bounds[4]);
  return 3;
}

static int l_lovrModelDataGetCenter(lua_State* L) {
  ModelData* model = luax_checktype(L, 1, ModelData);
  float bounds[6];
  luax_checkboundingbox(L, 2, model, bounds);
  lua_pushnumber(L, (bounds[0] + bounds[1]) / 2.f);
  lua_pushnumber(L, (bounds[2] + bounds[3]) / 2.f);
  lua_pushnumber(L, (bounds[4] + bounds[5]) / 2.f);
  return 3;
}

static int l_lovrModelDataGetBoundingBox(lua_State* L) {
  ModelData* model = luax_checktype(L, 1, ModelData);
  float bounds[6];
  luax_checkboundingbox(L, 2, model, bounds);
  lua_pushnumber(L, bounds[0]);
  lua_pushnumber(L, bounds[1]);
  lua_pushnumber(L, bounds[2]);
  lua_pushnumber(L, bounds[3]);
  lua_pushnumber(L, bounds[4]);
  lua_pushnumber(L, bounds[5]);
  return 6;
}

static int l_lovrModelDataGetBoundingSphere(lua_State* L) {
  ModelData* model = luax_checktype(L, 1, ModelData);
  float sphere[4];
  if (lua_type(L, 2) == LUA_TNONE) {
    lovrModelDataGetBoundingSphere(model, sphere);
  } else {
    uint32_t mesh = luax_checku32(L, 2) - 1;
    luax_check(L, mesh < model->meshCount, "Invalid mesh index '%d'", mesh + 1);

    uint32_t part = ~0u;
    if (lua_type(L, 3) != LUA_TNONE) {
      part = luax_checku32(L, 3);
      luax_check(L, part < model->meshes[mesh].partCount, "Invalid part index '%d'", part + 1);
    }

    lovrModelDataGetMeshBoundingSphere(model, mesh, part, sphere);
  }
  lua_pushnumber(L, sphere[0]);
  lua_pushnumber(L, sphere[1]);
  lua_pushnumber(L, sphere[2]);
  lua_pushnumber(L, sphere[3]);
  return 4;
}

static int l_lovrModelDataGetImageCount(lua_State* L) {
  ModelData* model = luax_checktype(L, 1, ModelData);
  lua_pushinteger(L, model->imageCount);
  return 1;
}

static int l_lovrModelDataGetImage(lua_State* L) {
  ModelData* model = luax_checktype(L, 1, ModelData);
  uint32_t index = luax_checku32(L, 2) - 1;
  luax_check(L, index < model->imageCount, "Invalid image index '%d'", index + 1);
  luax_pushtype(L, Image, model->images[index]);
  return 1;
}

static int l_lovrModelDataGetMaterialCount(lua_State* L) {
  ModelData* model = luax_checktype(L, 1, ModelData);
  lua_pushinteger(L, model->materialCount);
  return 1;
}

static int l_lovrModelDataGetMaterialName(lua_State* L) {
  ModelData* model = luax_checktype(L, 1, ModelData);
  uint32_t index = luax_checku32(L, 2) - 1;
  luax_check(L, index < model->nodeCount, "Invalid material index '%d'", index + 1);
  lua_pushstring(L, model->materials[index].name);
  return 1;
}

static int l_lovrModelDataGetMaterial(lua_State* L) {
  ModelData* model = luax_checktype(L, 1, ModelData);
  ModelMaterial* material = &model->materials[luax_checkmaterialindex(L, 2, model)];

  lua_newtable(L);

  lua_createtable(L, 4, 0);
  lua_pushnumber(L, material->color[0]);
  lua_rawseti(L, -2, 1);
  lua_pushnumber(L, material->color[1]);
  lua_rawseti(L, -2, 2);
  lua_pushnumber(L, material->color[2]);
  lua_rawseti(L, -2, 3);
  lua_pushnumber(L, material->color[3]);
  lua_rawseti(L, -2, 4);
  lua_setfield(L, -2, "color");

  lua_createtable(L, 4, 0);
  lua_pushnumber(L, material->glow[0]);
  lua_rawseti(L, -2, 1);
  lua_pushnumber(L, material->glow[1]);
  lua_rawseti(L, -2, 2);
  lua_pushnumber(L, material->glow[2]);
  lua_rawseti(L, -2, 3);
  lua_pushnumber(L, material->glow[3]);
  lua_rawseti(L, -2, 4);
  lua_setfield(L, -2, "glow");

  lua_createtable(L, 2, 0);
  lua_pushnumber(L, material->uvShift[0]);
  lua_rawseti(L, -2, 1);
  lua_pushnumber(L, material->uvShift[1]);
  lua_rawseti(L, -2, 2);
  lua_setfield(L, -2, "uvShift");

  lua_createtable(L, 2, 0);
  lua_pushnumber(L, material->uvShift[0]);
  lua_rawseti(L, -2, 1);
  lua_pushnumber(L, material->uvShift[1]);
  lua_rawseti(L, -2, 2);
  lua_setfield(L, -2, "uvScale");

  lua_pushnumber(L, material->metalness), lua_setfield(L, -2, "metalness");
  lua_pushnumber(L, material->roughness), lua_setfield(L, -2, "roughness");
  lua_pushnumber(L, material->clearcoat), lua_setfield(L, -2, "clearcoat");
  lua_pushnumber(L, material->clearcoatRoughness), lua_setfield(L, -2, "clearcoatRoughness");
  lua_pushnumber(L, material->occlusionStrength), lua_setfield(L, -2, "occlusionStrength");
  lua_pushnumber(L, material->normalScale), lua_setfield(L, -2, "normalScale");
  lua_pushnumber(L, material->alphaCutoff), lua_setfield(L, -2, "alphaCutoff");

#define PUSH_IMAGE(t) if (material->t != ~0u) luax_pushtype(L, Image, model->images[material->t]), lua_setfield(L, -2, #t)
  PUSH_IMAGE(texture);
  PUSH_IMAGE(glowTexture);
  PUSH_IMAGE(metalnessTexture);
  PUSH_IMAGE(roughnessTexture);
  PUSH_IMAGE(clearcoatTexture);
  PUSH_IMAGE(occlusionTexture);
  PUSH_IMAGE(normalTexture);

  return 1;
}

static int l_lovrModelDataGetAnimationCount(lua_State* L) {
  ModelData* model = luax_checktype(L, 1, ModelData);
  lua_pushinteger(L, model->animationCount);
  return 1;
}

static int l_lovrModelDataGetAnimationName(lua_State* L) {
  ModelData* model = luax_checktype(L, 1, ModelData);
  uint32_t index = luax_checku32(L, 2) - 1;
  luax_check(L, index < model->animationCount, "Invalid animation index '%d'", index + 1);
  lua_pushstring(L, model->animations[index].name);
  return 1;
}

static int l_lovrModelDataGetAnimationDuration(lua_State* L) {
  ModelData* model = luax_checktype(L, 1, ModelData);
  ModelAnimation* animation = &model->animations[luax_checkanimationindex(L, 2, model)];
  lua_pushnumber(L, animation->duration);
  return 1;
}

static int l_lovrModelDataGetAnimationChannelCount(lua_State* L) {
  ModelData* model = luax_checktype(L, 1, ModelData);
  ModelAnimation* animation = &model->animations[luax_checkanimationindex(L, 2, model)];
  lua_pushinteger(L, animation->channelCount);
  return 1;
}

static int l_lovrModelDataGetAnimationNode(lua_State* L) {
  ModelData* model = luax_checktype(L, 1, ModelData);
  ModelAnimation* animation = &model->animations[luax_checkanimationindex(L, 2, model)];
  uint32_t index = luax_checku32(L, 3) - 1;
  luax_check(L, index < animation->channelCount, "Invalid channel index '%d'", index + 1);
  ModelAnimationChannel* channel = &animation->channels[index];
  lua_pushinteger(L, channel->nodeIndex);
  return 1;
}

static int l_lovrModelDataGetAnimationProperty(lua_State* L) {
  ModelData* model = luax_checktype(L, 1, ModelData);
  ModelAnimation* animation = &model->animations[luax_checkanimationindex(L, 2, model)];
  uint32_t index = luax_checku32(L, 3) - 1;
  luax_check(L, index < animation->channelCount, "Invalid channel index '%d'", index + 1);
  ModelAnimationChannel* channel = &animation->channels[index];
  luax_pushenum(L, AnimationProperty, channel->property);
  return 1;
}

static int l_lovrModelDataGetAnimationSmoothMode(lua_State* L) {
  ModelData* model = luax_checktype(L, 1, ModelData);
  ModelAnimation* animation = &model->animations[luax_checkanimationindex(L, 2, model)];
  uint32_t index = luax_checku32(L, 3) - 1;
  luax_check(L, index < animation->channelCount, "Invalid channel index '%d'", index + 1);
  ModelAnimationChannel* channel = &animation->channels[index];
  luax_pushenum(L, SmoothMode, channel->smoothing);
  return 1;
}

static int l_lovrModelDataGetAnimationKeyframeCount(lua_State* L) {
  ModelData* model = luax_checktype(L, 1, ModelData);
  ModelAnimation* animation = &model->animations[luax_checkanimationindex(L, 2, model)];
  uint32_t index = luax_checku32(L, 3) - 1;
  luax_check(L, index < animation->channelCount, "Invalid channel index '%d'", index + 1);
  ModelAnimationChannel* channel = &animation->channels[index];
  lua_pushinteger(L, channel->keyframeCount);
  return 1;
}

static int l_lovrModelDataGetAnimationKeyframe(lua_State* L) {
  ModelData* model = luax_checktype(L, 1, ModelData);
  ModelAnimation* animation = &model->animations[luax_checkanimationindex(L, 2, model)];
  uint32_t index = luax_checku32(L, 3) - 1;
  luax_check(L, index < animation->channelCount, "Invalid channel index '%d'", index + 1);
  ModelAnimationChannel* channel = &animation->channels[index];
  uint32_t keyframe = luax_checku32(L, 4) - 1;
  luax_check(L, keyframe < channel->keyframeCount, "Invalid keyframe index '%d'", keyframe + 1);
  lua_pushnumber(L, channel->times[keyframe]);
  int count;
  switch (channel->property) {
    case PROP_TRANSLATION: count = 3; break;
    case PROP_ROTATION: count = 4; break;
    case PROP_SCALE: count = 3; break;
    case PROP_WEIGHTS: count = model->meshes[model->nodes[channel->nodeIndex].mesh].blendShapeCount; break;
  }
  for (int i = 0; i < count; i++) {
    lua_pushnumber(L, channel->data[keyframe * count + i]);
  }
  return count + 1;
}

static int l_lovrModelDataGetSkinCount(lua_State* L) {
  ModelData* model = luax_checktype(L, 1, ModelData);
  lua_pushinteger(L, model->skinCount);
  return 1;
}

static int l_lovrModelDataGetSkinJoints(lua_State* L) {
  ModelData* model = luax_checktype(L, 1, ModelData);
  uint32_t index = luax_checku32(L, 2) - 1;
  luax_check(L, index < model->skinCount, "Invalid skin index '%d'", index + 1);
  ModelSkin* skin = &model->skins[index];
  lua_createtable(L, skin->jointCount, 0);
  for (uint32_t i = 0; i < skin->jointCount; i++) {
    lua_pushinteger(L, skin->joints[i]);
    lua_rawseti(L, -2, i + 1);
  }
  return 1;
}

static int l_lovrModelDataGetSkinInverseBindMatrix(lua_State* L) {
  ModelData* model = luax_checktype(L, 1, ModelData);
  uint32_t index = luax_checku32(L, 2) - 1;
  luax_check(L, index < model->skinCount, "Invalid skin index '%d'", index + 1);
  ModelSkin* skin = &model->skins[index];
  uint32_t joint = luax_checku32(L, 3) - 1;
  luax_check(L, index < skin->jointCount, "Invalid joint index '%d'", joint + 1);
  if (!skin->inverseBindMatrices) return lua_pushnil(L), 1;
  float* m = skin->inverseBindMatrices + joint * 16;
  for (uint32_t i = 0; i < 16; i++) {
    lua_pushnumber(L, m[i]);
  }
  return 16;
}

static int l_lovrModelDataGetBlendShapeCount(lua_State* L) {
  ModelData* model = luax_checktype(L, 1, ModelData);
  lua_pushinteger(L, model->blendShapeCount);
  return 1;
}

static int l_lovrModelDataGetBlendShapeName(lua_State* L) {
  ModelData* model = luax_checktype(L, 1, ModelData);
  uint32_t index = luax_checku32(L, 2) - 1;
  luax_check(L, index < model->blendShapeCount, "Invalid blend shape index '%d'", index + 1);
  lua_pushstring(L, model->blendShapes[index].name);
  return 1;
}

const luaL_Reg lovrModelData[] = {
  { "getMetadata", l_lovrModelDataGetMetadata },
  { "getRootNode", l_lovrModelDataGetRootNode },
  { "getNodeCount", l_lovrModelDataGetNodeCount },
  { "getNodeName", l_lovrModelDataGetNodeName },
  { "getNodeChild", l_lovrModelDataGetNodeChild },
  { "getNodeChildren", l_lovrModelDataGetNodeChildren }, // Deprecated
  { "getNodeSibling", l_lovrModelDataGetNodeSibling },
  { "getNodeParent", l_lovrModelDataGetNodeParent },
  { "getNodePosition", l_lovrModelDataGetNodePosition },
  { "getNodeOrientation", l_lovrModelDataGetNodeOrientation },
  { "getNodeScale", l_lovrModelDataGetNodeScale },
  { "getNodePose", l_lovrModelDataGetNodePose },
  { "getNodeTransform", l_lovrModelDataGetNodeTransform },
  { "getNodeMesh", l_lovrModelDataGetNodeMesh },
  { "getNodeSkin", l_lovrModelDataGetNodeSkin },
  { "getMeshCount", l_lovrModelDataGetMeshCount },
  { "getMeshPartCount", l_lovrModelDataGetMeshPartCount },
  { "getMeshDrawMode", l_lovrModelDataGetMeshDrawMode },
  { "getMeshDrawRange", l_lovrModelDataGetMeshDrawRange },
  { "getMeshBaseVertex", l_lovrModelDataGetMeshBaseVertex },
  { "getMeshMaterial", l_lovrModelDataGetMeshMaterial },
  { "getTriangles", l_lovrModelDataGetTriangles },
  { "getTriangleCount", l_lovrModelDataGetTriangleCount },
  { "getVertexCount", l_lovrModelDataGetVertexCount },
  { "getWidth", l_lovrModelDataGetWidth },
  { "getHeight", l_lovrModelDataGetHeight },
  { "getDepth", l_lovrModelDataGetDepth },
  { "getDimensions", l_lovrModelDataGetDimensions },
  { "getCenter", l_lovrModelDataGetCenter },
  { "getBoundingBox", l_lovrModelDataGetBoundingBox },
  { "getBoundingSphere", l_lovrModelDataGetBoundingSphere },
  { "getImageCount", l_lovrModelDataGetImageCount },
  { "getImage", l_lovrModelDataGetImage },
  { "getMaterialCount", l_lovrModelDataGetMaterialCount },
  { "getMaterialName", l_lovrModelDataGetMaterialName },
  { "getMaterial", l_lovrModelDataGetMaterial },
  { "getAnimationCount", l_lovrModelDataGetAnimationCount },
  { "getAnimationName", l_lovrModelDataGetAnimationName },
  { "getAnimationDuration", l_lovrModelDataGetAnimationDuration },
  { "getAnimationChannelCount", l_lovrModelDataGetAnimationChannelCount },
  { "getAnimationNode", l_lovrModelDataGetAnimationNode },
  { "getAnimationProperty", l_lovrModelDataGetAnimationProperty },
  { "getAnimationSmoothMode", l_lovrModelDataGetAnimationSmoothMode },
  { "getAnimationKeyframeCount", l_lovrModelDataGetAnimationKeyframeCount },
  { "getAnimationKeyframe", l_lovrModelDataGetAnimationKeyframe },
  { "getSkinCount", l_lovrModelDataGetSkinCount },
  { "getSkinJoints", l_lovrModelDataGetSkinJoints },
  { "getSkinInverseBindMatrix", l_lovrModelDataGetSkinInverseBindMatrix },
  { "getBlendShapeCount", l_lovrModelDataGetBlendShapeCount },
  { "getBlendShapeName", l_lovrModelDataGetBlendShapeName },
  { NULL, NULL }
};
