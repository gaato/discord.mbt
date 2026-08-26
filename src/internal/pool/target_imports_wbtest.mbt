///|
#cfg(not(target="native"))
let _keep_native_only_wbtest_imports : Unit = {
  ignore(@socket.unimplemented)
  ignore(@io.pipe)
}
