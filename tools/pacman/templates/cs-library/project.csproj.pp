<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003" Sdk="Microsoft.NET.Sdk" ToolsVersion="15.0">
  <PropertyGroup>
    <EnableDefaultCompileItems>false</EnableDefaultCompileItems>
  </PropertyGroup>
  <PropertyGroup>
    <AssemblyName>[[ $_.Directory.Name ]]</AssemblyName>
    <RootNamespace>[[ $_.Directory.Name ]]</RootNamespace>
    <TargetFrameworks>netstandard2.0</TargetFrameworks>
    <DefineConstants>$(DefineConstants);JETBRAINS_ANNOTATIONS</DefineConstants>
  </PropertyGroup>
  <PropertyGroup Condition=" '$(Configuration)' == 'Release' ">
    <DefineConstants>$(DefineConstants);RELEASE</DefineConstants>
  </PropertyGroup>
  <ItemGroup>
    <Compile Include="**\*.cs" Exclude="obj/**" />
  </ItemGroup>
</Project>