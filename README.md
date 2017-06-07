# Powershell
Collection of Powershell Scripts


#Application Configuration File
The Application Config class can be used with Powershell 5 and above. The class can be instantiated using $x = [AppConfig]::new($configfile)

Th class processes a file in xml format using "add" method in tags. The class will process all attributes in the tag and any sub "add" elements.

For each top level "add" element a Dictionary is created within the object at runtime and is accessible by $x.item
