// Generates docs/packages.mmd and docs/packages.svg from the moon.pkg import
// declarations of the main module. The graph covers the public packages
// (examples, the guide, and internal/* are omitted) and is transitively
// reduced: an edge is drawn only when the dependency is not already implied
// by another drawn edge. Native-only packages (no non-test .mbt file compiles
// on js) are shaded amber. The SVG is rendered in-process with mizchi/moomaid.
//
//   moon run . --target native             regenerate both files
//   moon run . --target native -- --check  fail if docs/packages.mmd is stale

///|
const MODULE_PREFIX = "gaato/discord/"

///|
fn excluded(name : String) -> Bool {
  for prefix in ["examples", "guide", "internal"] {
    if name == prefix || name.has_prefix("\{prefix}/") {
      return true
    }
  }
  false
}

///|
fn find_root() -> String raise {
  for candidate in [".", "..", "../..", "../../.."] {
    if @fs.path_exists("\{candidate}/src/moon.pkg") &&
      @fs.path_exists("\{candidate}/moon.mod") &&
      @fs.read_file_to_string("\{candidate}/moon.mod").contains(
        "name = \"gaato/discord\"",
      ) {
      return candidate
    }
  }
  fail("could not locate the discord.mbt repository root")
}

///|
/// Internal, non-test dependencies declared by one moon.pkg file.
fn parse_deps(text : String) -> Set[String] {
  let deps : Set[String] = Set([])
  let block : Array[String] = []
  let mut in_import = false
  for line in text.split("\n") {
    if !in_import {
      if line.contains("import") && line.contains("{") {
        in_import = true
        block.clear()
      }
    } else if line.contains("}") {
      if !line.contains("for \"test\"") {
        for dep in block {
          if !excluded(dep) {
            deps.add(dep)
          }
        }
      }
      in_import = false
    } else {
      for part in line.split("\"") {
        if part.has_prefix(MODULE_PREFIX) {
          block.push(part[MODULE_PREFIX.length():].to_owned())
        }
      }
    }
  }
  deps
}

///|
/// Whether the package produces usable js output: true when at least one
/// non-test .mbt file is not gated to other targets by the moon.pkg
/// `targets` block. Packages that compile empty on js count as native-only.
fn js_capable(text : String, entries : Array[String]) -> Bool {
  let gated : Set[String] = Set([])
  for line in text.split("\n") {
    if line.contains("supported_targets") && !line.contains("js") {
      return false
    }
    if line.contains("\": [") && !line.contains("\"js\"") {
      for part in line.split("\"") {
        if part.has_suffix(".mbt") {
          gated.add(part.to_owned())
        }
      }
    }
  }
  for entry in entries {
    if entry.has_suffix(".mbt") &&
      !entry.has_suffix("_test.mbt") &&
      !entry.has_suffix("_wbtest.mbt") &&
      !gated.contains(entry) {
      return true
    }
  }
  false
}

///|
fn collect_edges(
  edges : Map[String, Set[String]],
  native_only : Set[String],
  src : String,
  rel : String,
) -> Unit raise {
  let dir = if rel == "" { src } else { "\{src}/\{rel}" }
  let entries = @fs.read_dir(dir)
  if entries.contains("moon.pkg") {
    let name = if rel == "" { "discord" } else { rel }
    let text = @fs.read_file_to_string("\{dir}/moon.pkg")
    edges[name] = parse_deps(text)
    if !js_capable(text, entries) {
      native_only.add(name)
    }
  }
  for entry in entries {
    let child = if rel == "" { entry } else { "\{rel}/\{entry}" }
    if !excluded(child) && @fs.is_dir("\{src}/\{child}") {
      collect_edges(edges, native_only, src, child)
    }
  }
}

///|
/// Every package reachable from `node` through dependency edges.
fn reach(
  edges : Map[String, Set[String]],
  memo : Map[String, Set[String]],
  node : String,
) -> Set[String] {
  match memo.get(node) {
    Some(cached) => cached
    None => {
      let result : Set[String] = Set([])
      match edges.get(node) {
        Some(deps) =>
          for dep in deps {
            result.add(dep)
            for transitive in reach(edges, memo, dep) {
              result.add(transitive)
            }
          }
        None => ()
      }
      memo[node] = result
      result
    }
  }
}

///|
const NATIVE_FILL = "#FFE1B8"

///|
fn render_edge_lines(edges : Map[String, Set[String]]) -> Array[String] {
  let memo : Map[String, Set[String]] = Map([])
  let lines : Array[String] = []
  let nodes = edges.keys().collect()
  nodes.sort()
  for node in nodes {
    let deps = match edges.get(node) {
      Some(deps) => deps
      None => continue
    }
    let kept : Array[String] = []
    for dep in deps {
      let mut implied = false
      for other in deps {
        if other != dep && reach(edges, memo, other).contains(dep) {
          implied = true
        }
      }
      if !implied {
        kept.push(dep)
      }
    }
    kept.sort()
    for dep in kept {
      lines.push("  \{node} --> \{dep}")
    }
  }
  lines
}

///|
/// The checked-in mermaid source: edges plus a class shading the
/// native-only packages, so mermaid renderers show the same split as the
/// generated SVG.
fn render_mermaid(
  edges : Map[String, Set[String]],
  native_only : Set[String],
) -> String {
  let lines : Array[String] = [
    "graph TD",
    "  classDef nativeOnly fill:\{NATIVE_FILL},stroke:#27272A,color:#27272A",
  ]
  for line in render_edge_lines(edges) {
    lines.push(line)
  }
  let shaded = native_only.iter().collect()
  shaded.sort()
  if shaded.length() > 0 {
    let joined = shaded.join(",")
    lines.push("  class \{joined} nativeOnly")
  }
  lines.join("\n") + "\n"
}

///|
/// moomaid ignores classDef/class statements, so the SVG is rendered from
/// the bare edges and the native-only node rectangles are recolored here.
/// Each node is emitted as a `<g id="name">` group wrapping its rect.
fn recolor_svg(svg : String, native_only : Set[String]) -> String {
  let out : Array[String] = []
  let mut shade = false
  for view in svg.split("\n") {
    let line = view.to_owned()
    if line.has_prefix("<g id=\"") {
      let parts = line.split("\"").collect()
      shade = parts.length() > 1 && native_only.contains(parts[1].to_owned())
      out.push(line)
    } else if shade && line.has_prefix("<rect") {
      out.push(
        line.replace(old="fill=\"#FFFFFF\"", new="fill=\"\{NATIVE_FILL}\""),
      )
      shade = false
    } else {
      out.push(line)
    }
  }
  out.join("\n")
}

///|
fn run(check~ : Bool) -> Unit raise {
  let root = find_root()
  let edges : Map[String, Set[String]] = Map([])
  let native_only : Set[String] = Set([])
  collect_edges(edges, native_only, "\{root}/src", "")
  let mermaid = render_mermaid(edges, native_only)
  let mmd_path = "\{root}/docs/packages.mmd"
  if check {
    let current = if @fs.path_exists(mmd_path) {
      @fs.read_file_to_string(mmd_path)
    } else {
      ""
    }
    if current != mermaid {
      println("docs/packages.mmd is stale; regenerate with tools/package_graph")
      @sys.exit(1)
    }
    return
  }
  if !@fs.path_exists("\{root}/docs") {
    @fs.create_dir("\{root}/docs")
  }
  @fs.write_string_to_file(mmd_path, mermaid)
  let plain = "graph TD\n" + render_edge_lines(edges).join("\n") + "\n"
  @fs.write_string_to_file(
    "\{root}/docs/packages.svg",
    recolor_svg(@moomaid.experimental_render_to_svg(plain), native_only) + "\n",
  )
  println("wrote docs/packages.mmd and docs/packages.svg")
}

///|
fn main {
  run(check=@sys.get_cli_args().contains("--check")) catch {
    err => {
      println("package_graph failed: \{err}")
      @sys.exit(1)
    }
  }
}
