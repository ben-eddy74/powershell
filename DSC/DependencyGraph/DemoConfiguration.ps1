Configuration DemoConfiguration
{
  param
  (
    [Parameter()]
    [string] $CertificateAuthorityHost = 'srv1.mydomain.internal',

    [Parameter()]
    [string] $CertificateAuthority = 'myCA',

    [Parameter()]
    [pscredential] $CertificateAuthorityCredential
  )

  Import-DscResource -ModuleName CertificateDsc
  Import-DscResource -ModuleName WebAdministrationDsc

  Node localhost
  {
    WaitForCertificateServices RootCA
    {
      CARootName   = $CertificateAuthority
      CAServerFQDN = $CertificateAuthorityHost
    }

    CertReq website1
    {
      CARootName          = $CertificateAuthority
      CAServerFQDN        = $CertificateAuthorityHost
      Subject             = 'My website'
      KeyLength           = '2048'
      Exportable          = $false
      ProviderName        = 'Microsoft RSA SChannel Cryptographic Provider'
      OID                 = '1.3.6.1.5.5.7.3.1'
      KeyUsage            = '0xa0'
      CertificateTemplate = "WebServer"
      SubjectAltName      = "dns=www.mydomain.internal"
      AutoRenew           = $true
      FriendlyName        = 'My website'
      Credential          = $CertificateAuthorityCredential
      KeyType             = 'RSA'
      RequestType         = 'CMC'
      DependsOn           = "[WaitForCertificateServices]RootCA"
    }

    WindowsFeature IIS
    {
      Ensure          = 'Present'
      Name            = 'Web-Server'
    }

    WebSite website1
        {
            Ensure          = 'Present'
            Name            = 'My website'
            State           = 'Started'
            PhysicalPath    = 'C:\inetpub\wwwroot\myWebsite'
            BindingInfo     = @(
                DSC_WebBindingInformation
                {
                    Protocol              = 'HTTPS'
                    Port                  = 8443
                    CertificateSubject    = 'CN=My website'
                    CertificateStoreName  = 'My'
                }
            )
            DependsOn       = '[CertReq]website1', '[WindowsFeature]IIS'
        }
  }
}
