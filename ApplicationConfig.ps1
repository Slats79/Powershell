param($path, [switch]$test)

Class ApplicationConfig
{
    [string]$configfile

    ApplicationConfig([string]$configfile)
    {
        if(Test-Path $configfile)
        {
            $this.configfile = $configfile
            $this.ProcessConfig()
        }
        else
        {
            Write-Error "Config file is not accessible"
        }   

    }

    [void]ProcessConfig()
    {
        #$this.config = @{}
        $appConfig = [xml](get-content $this.configfile)                            
        $appconfig.configuration.appSettings.add | %{                     
            $section = $_.name
            if($($_.enabled) -notmatch "false")
            {                
                $this | Add-Member -Name $section -MemberType NoteProperty -Value (New-Object System.Collections.Specialized.OrderedDictionary)
                if($_.add)
                {
                    $_.add | %{
                        $item=$this.ProcessSubSections($_)
                        if($item){$this.($section)+=$item}
                    }
                                               
                }
                else
                {
                    $item=$this.unpack($_)
                    if($item){$this.($section) = $item}
                }     
            }
        }
    }
    [object]ProcessSubSections($section)
    {
        # Create Ordered HashTable
        if($($section.enabled) -notmatch "false")
        {
            $ret = New-Object System.Collections.Specialized.OrderedDictionary                                          
            $section | %{                           
                #we need to loop through each item and look for ADD sections
                $_ | %{                
                    if($_.add)
                    {                                         
                        # Any add sections need to rerun this method to generate hash of attributes                                      
                        $subitem=$this.ProcessSubSections($_.add)                     
                    
                        #Add sub hashtable to main table for this method
                        if($subitem)
                        {
                            $ret[$_.name]+=$subitem
                        }
                    } 
                                        
                }                      
                $item = $this.unpack($_)              
                try{
                    if($item)
                    {
                        $ret[$_.name]+=$item
                    }
                }
                catch
                {
                }                               
            }                     
            return $ret
        }
        else{return $null}
    }
    
    #blank validate method inherited by other classes
    [object]Validate($item)
    {               
        return $item                   
    }

    # This method unpacks the xml attributes for processing
    [object]Unpack($section)
    {
        $attrhash=New-Object System.Collections.Specialized.OrderedDictionary
        if($($section.enabled) -notmatch "false")
        {
            $name=$section.name                    
            # We need to select the attributes in XML tag for processing
            $attributes = $section.Attributes | ?{$_.Name -ne "name" -and ($_.Value).length -gt 0} | select Name,Value
        
            # Loop through attributes and add to hashtable to be added to main config
            $attributes | %{            
                if($_.value -ne $null)                    
                {               
                    #unpack and validate sub sections in Config file                               
                    $item=$this.Validate($_)                   
                    $attrhash.add($_.name, $item.value)
             
                }                                                                                                           
            }
            return $attrhash
        }
        else
        {
            return $null
        }
    }

}


# Class implements specific functionality for File Move Configurations
Class FileAppConfig : ApplicationConfig
{
    [string]$localpath
    FileAppConfig([string]$path) : base($path)
    {       
        $this.localpath=split-path $this.configfile
    }

    
    [object]Validate($item)
    {
        if($item.name -eq 'filepattern'){$item.value=$item.value -replace '[[+?()\\.]','\$&' -replace "\*", ".*"}
        #validate file paths
        if($item.value -match '^(?:[a-zA-Z])\[\w\s]+$:|(?<=\\{2}).*?(?=\\\w*).[\w\s]+$')
        {
            #Add slash to path
            $item.value="$($item.value)\"

            #Create Directories
            $item.value -Split ";" | %{if((Test-Path $_) -eq $false){mkdir $_ -Force}}
        }        
        return $item               
    }

    [void]SetupPaths()
    {
        $localdirectories=@("archive","source","destination")

        $localdirectories | %{
            if ((test-path $_) -eq $false)
            {
                mkdir "$($this.localpath)\$_" -force
            }
        }
    }
}
 
if($test)
{
    Write-Host -ForegroundColor Green "Processing Application Configuration"
    $config=[FileAppConfig]::new($path)

    Write-Host -ForegroundColor Green "System Section"
    $config.system

    Write-Host -ForegroundColor Green "Moves Section"
    #$config.moves


    $config.moves.getenumerator() | %{Write-Host "$($_.name) - $($_.value.description)"}
}