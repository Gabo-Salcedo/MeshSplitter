# 📄 Documento de Diseño: Plugin de Importación Modular de Modelos 3D para Godot

## 🌟 Objetivo
Crear un plugin para Godot Engine que reemplace el proceso tradicional de importación de archivos 3D (·glb, ·fbx, ·gltf, ·obj) por un flujo **modular y ordenado**, similar al que ofrecen Unity o Unreal Engine. El plugin debe destripar el modelo 3D en partes reutilizables: meshes, materiales, rigging, animaciones individuales y una librería de animaciones.

## 🔹 Entradas Soportadas
| Formato | Mesh | Material | Rigging | Animaciones |
|--------|------|----------|---------|-------------|
| .GLB   | ✅   | ✅       | ✅      | ✅          |
| .GLTF  | ✅   | ✅       | ✅      | ✅          |
| .FBX   | ✅   | ✅       | ✅      | ✅          |
| .OBJ   | ✅   | ✅       | ❌      | ❌          |

## 🔹 Proceso General

```
[3D Source File] (.glb/.fbx/.gltf/.obj)
	 |
	 |---> Importador (plugin)
			 |
			 +---> mesh/  -> archivos .mesh / .res / .tres
			 +---> materials/ -> materiales separados .tres
			 +---> rig/ -> rigg.tres (si aplica)
			 +---> anims/ -> animaciones individuales .anim
			 +---> anims/AnimationLibrary.tres
			 +---> scene/ -> escena limpia reconstruida .tscn
			 +---> manifest.json (opcional)
```

## 🔧 Arquitectura del Plugin

### 1. `plugin.cfg`
Archivo de definición del plugin.

### 2. `plugin.gd`
Clase principal `EditorPlugin` que:
- Agrega un botón en el editor.
- Instancia una UI simple para elegir archivo o carpeta.

### 3. `splitter.gd`
Script con funciones estáticas para:
- Separar meshes.
- Extraer materiales.
- Detectar y guardar el rig.
- Extraer animaciones.
- Crear `AnimationLibrary.tres`.
- Crear escena `.tscn` limpia.
- Crear `manifest.json` con las rutas.

### 4. `ui_panel.tscn` + `ui_panel.gd`
Interfaz gráfica que permite ejecutar el destripe desde un botón.

## 💡 Reglas de Extracción
- Meshes: `MeshInstance3D.mesh` extraído y guardado por nombre.
- Materiales: se extraen desde cada surface override.
- Rig: se busca nodo `Skeleton3D` o `Armature`.
- Animaciones: se buscan `AnimationPlayer` y sus `animations`.
- Librería: se crea `AnimationLibrary` con `add_animation()` por cada clip.

## 📂 Estructura de Salida Generada

```
model_name/
  |-- mesh/
  |     |-- body.mesh
  |     |-- head.mesh
  |
  |-- materials/
  |     |-- body_mat.tres
  |     |-- head_mat.tres
  |
  |-- rig/
  |     |-- skeleton.tres
  |
  |-- anims/
  |     |-- run.anim
  |     |-- idle.anim
  |     |-- AnimationLibrary.tres
  |
  |-- scene/
  |     |-- model_clean.tscn
  |
  |-- manifest.json
```

## 🛋️ Funcionalidades Opcionales
- opcion de Evitar sobrescritura: crear subcarpetas por timestamp.
- Mostrar previsualización antes de guardar.
- Elegir carpetas de salida personalizadas.

## ✅ Beneficios
- Separación clara de componentes reutilizables.
- Flujo de trabajo profesional al estilo Unity/Unreal.
- Escenas finales limpias y listas para instanciar.
- Reduce errores y tiempo de organización manual.

## 🚫 Limitaciones
- `.obj` no soporta rig ni animaciones.
- No hay retargeting de animaciones entre rigs distintos (por ahora).

## 🔎 Futuras Mejoras
- Retargeting entre rigs compatibles.
- UI para configurar prefijos, sufijos, escalar, etc.
- Integración con sistema de importación automática de Godot.

---

Cualquier duda o mejora, lo seguimos puliendo. Este plugin tiene futuro largo si lo afilamos bien.
