
Enum eResourceType {
  VirtualMachine
  BlockStorage
}

Class ResourceType : System.Management.Automation.IValidateSetValuesGenerator {  
  [String[]] GetValidValues() {          
    return [eResourceType].GetEnumNames()
  }
}

Enum eProvider {
  AWS
  Azure
}

Class Provider : System.Management.Automation.IValidateSetValuesGenerator {  
  [String[]] GetValidValues() {          
    return [eProvider].GetEnumNames()
  }
}

