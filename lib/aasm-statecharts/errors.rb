# errors raised

module AASM_StateChart

  class AASM_StateChart_Error < StandardError
  end

  class AASM_NoModels < AASM_StateChart_Error
  end

  class NoAASM_Error < AASM_StateChart_Error
  end

  class NoStates_Error < AASM_StateChart_Error
  end

  class BadFormat_Error < AASM_StateChart_Error
  end

  class NoConfigFile_Error < AASM_StateChart_Error
  end

  class BadConfigFile_Error < AASM_StateChart_Error
  end

  class BadOutputDir_Error < AASM_StateChart_Error
  end

  class NoRailsConfig_Error < AASM_StateChart_Error
  end

  class BadPath_Error < AASM_StateChart_Error
  end

  class PathNotLoaded < AASM_StateChart_Error
  end

  class ModelNotLoaded < AASM_StateChart_Error
  end

end # module