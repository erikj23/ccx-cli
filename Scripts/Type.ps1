
Enum ResourceTypes {
  VirtualMachine=1
  vm=1
  BlockStorage = 2
  block=2
  ObjectStorage=3
  object=3
}

Class ResourceType : System.Management.Automation.IValidateSetValuesGenerator {  
  [String[]] GetValidValues() {          
    return [ResourceTypes].GetEnumNames()
  }
}

Enum Providers {
  AWS
  Azure
}

Class Provider : System.Management.Automation.IValidateSetValuesGenerator {  
  [String[]] GetValidValues() {          
    return [Providers].GetEnumNames()
  }
}

