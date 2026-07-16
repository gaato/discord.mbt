// Generates docs/packages.mmd and docs/packages.svg from the moon.pkg import
// declarations of the main module. The graph covers the public packages
// (examples, the guide, and internal/* are omitted) and is transitively
// reduced: an edge is drawn only when the dependency is not already implied
// by another drawn edge. The SVG is rendered in-process with mizchi/moomaid.
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
fn collect_edges(
  edges : Map[String, Set[String]],
  src : String,
  rel : String,
) -> Unit raise {
  let dir = if rel == "" { src } else { "\{src}/\{rel}" }
  let entries = @fs.read_dir(dir)
  if entries.contains("moon.pkg") {
    let name = if rel == "" { "discord" } else { rel }
    edges[name] = parse_deps(@fs.read_file_to_string("\{dir}/moon.pkg"))
  }
  for entry in entries {
    let child = if rel == "" { entry } else { "\{rel}/\{entry}" }
    if !excluded(child) && @fs.is_dir("\{src}/\{child}") {
      collect_edges(edges, src, child)
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
fn render_mermaid(edges : Map[String, Set[String]]) -> String {
  let memo : Map[String, Set[String]] = Map([])
  let lines : Array[String] = ["graph TD"]
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
  lines.join("\n") + "\n"
}

///|
fn run(check~ : Bool) -> Unit raise {
  let root = find_root()
  let edges : Map[String, Set[String]] = Map([])
  collect_edges(edges, "\{root}/src", "")
  let mermaid = render_mermaid(edges)
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
  @fs.write_string_to_file(
    "\{root}/docs/packages.svg",
    @moomaid.experimental_render_to_svg(mermaid) + "\n",
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
