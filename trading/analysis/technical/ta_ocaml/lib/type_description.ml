module Types (F : Ctypes.TYPE) = struct
  type ta_real = float
  let ta_real : ta_real F.typ = F.double

  type ta_retCode = int
  let ta_retCode : ta_retCode F.typ = F.int
end
