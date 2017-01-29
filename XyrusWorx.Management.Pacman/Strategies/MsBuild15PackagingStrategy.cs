using System;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Xml;
using System.Xml.Linq;
using JetBrains.Annotations;
using XyrusWorx.Diagnostics;
using XyrusWorx.IO;
using XyrusWorx.Management.ObjectModel;

namespace XyrusWorx.Management.Pacman.Strategies
{
	[UsedImplicitly(ImplicitUseKindFlags.InstantiatedWithFixedConstructorSignature)]
	class MsBuild15PackagingStrategy : PackagingStategy
	{
		public override PackageModel Process(BinaryContainer container, ILogWriter log = null)
		{
			if (container == null)
			{
				throw new ArgumentNullException(nameof(container));
			}

			if (!Open(container, null, out var root))
			{
				throw new InvalidDataException("The stream doesn't contain valid data to run the selected packaging strategy.");
			}

			var xmlns = root.Name.NamespaceName;
			var targetFrameworks = root.Descendants(XName.Get("TargetFrameworks", xmlns)).SelectMany(x => x.Value.Split(';')).ToArray();
			var result = new PackageModel(Path.GetFileNameWithoutExtension(container.Identifier));

			result.Title = root.Descendants(XName.Get("AssemblyTitle", xmlns)).FirstOrDefault()?.Value.NormalizeNull();
			result.Description = root.Descendants(XName.Get("Description", xmlns)).FirstOrDefault()?.Value.NormalizeNull();
			result.Copyright = root.Descendants(XName.Get("Copyright", xmlns)).FirstOrDefault()?.Value.NormalizeNull()?.Replace("$(Year)", DateTime.Today.Year.ToString());
			result.Authors.AddRange(root.Descendants(XName.Get("Authors", xmlns)).Take(1).Where(x => !string.IsNullOrWhiteSpace(x.Value)).Select(x => x.Value));
			result.Owners.AddRange(root.Descendants(XName.Get("Owners", xmlns)).Take(1).Where(x => !string.IsNullOrWhiteSpace(x.Value)).Select(x => x.Value));

			var versionString = root.Descendants(XName.Get("VersionPrefix", xmlns)).FirstOrDefault()?.Value.NormalizeNull();
			try
			{
				if (!string.IsNullOrWhiteSpace(versionString))
				{
					result.Version = SemanticVersion.Parse(versionString);
				}
			}
			catch
			{
				log?.WriteError($"Bad version: {versionString}");
			}

			var projectUrlString = root.Descendants(XName.Get("PackageProjectUrl", xmlns)).FirstOrDefault()?.Value.NormalizeNull();
			try
			{
				if (!string.IsNullOrWhiteSpace(projectUrlString))
				{
					result.ProjectUrl = new Uri(projectUrlString);
				}
			}
			catch (Exception exception)
			{
				log?.WriteError($"Bad project URL: {projectUrlString}. {exception.GetOriginalMessage()}");
			}

			var iconUrlString = root.Descendants(XName.Get("PackageIconUrl", xmlns)).FirstOrDefault()?.Value.NormalizeNull();
			try
			{
				if (!string.IsNullOrWhiteSpace(iconUrlString))
				{
					result.IconUrl = new Uri(iconUrlString);
				}
			}
			catch (Exception exception)
			{
				log?.WriteError($"Bad icon URL: {iconUrlString}. {exception.GetOriginalMessage()}");
			}

			var licenseUrlString = root.Descendants(XName.Get("PackageLicenseUrl", xmlns)).FirstOrDefault()?.Value.NormalizeNull();
			try
			{
				if (!string.IsNullOrWhiteSpace(licenseUrlString))
				{
					result.LicenseUrl = new Uri(licenseUrlString);
				}
			}
			catch (Exception exception)
			{
				log?.WriteError($"Bad license URL: {licenseUrlString}. {exception.GetOriginalMessage()}");
			}

			var languageString = root.Descendants(XName.Get("NeutralLanguage", xmlns)).FirstOrDefault()?.Value.NormalizeNull();
			try
			{
				if (!string.IsNullOrWhiteSpace(languageString))
				{
					result.Culture = CultureInfo.GetCultureInfo(languageString);
				}
			}
			catch (Exception exception)
			{
				log?.WriteError($"Bad language tag: {languageString}. {exception.GetOriginalMessage()}");
			}

			foreach (var targetFramework in targetFrameworks)
			{
				result.Files.Add(new PackageContentModel($"{targetFramework}\\*.dll", $"lib\\{targetFramework}"));
				result.Files.Add(new PackageContentModel($"{targetFramework}\\*.pdb", $"lib\\{targetFramework}"));
			}
			
			result.Files.Add(new PackageContentModel("../../**/*.cs", "src"));

			CollectDependencies(root, result, log);

			return result;
		}

		public override bool IsApplicable(BinaryContainer container, ILogWriter log = null)
		{
			if (container == null)
			{
				throw new ArgumentNullException(nameof(container));
			}

#pragma warning disable 168
			return Open(container, log, out var dummy);
#pragma warning restore 168
		}

		private bool Open(BinaryContainer container, ILogWriter log, out XElement root)
		{
			using (var reader = container.AsText().Read())
			{
				root = null;

				try
				{
					var document = XDocument.Load(reader);
					if (document.Root == null)
					{
						throw new XmlException("No root element!");
					}

					if (document.Root.Name.LocalName != "Project")
					{
						log?.WriteVerbose($"Not applicable to {nameof(MsBuild15PackagingStrategy)}. The root element \"{document.Root.Name.LocalName}\" doesn't have the expected name.");
						return false;
					}

					var toolsVersionAttribute = document.Root.Attribute("ToolsVersion")?.Value ?? "";
					if (!string.IsNullOrWhiteSpace(toolsVersionAttribute) && toolsVersionAttribute != "15.0")
					{
						log?.WriteVerbose($"Not applicable to {nameof(MsBuild15PackagingStrategy)}. The build tools version is not supported: {toolsVersionAttribute}.");
						return false;
					}

					root = document.Root;

					return true;
				}
				catch (XmlException exception)
				{
					log?.WriteVerbose($"Not applicable to {nameof(MsBuild15PackagingStrategy)}. The stream contains invalid XML. {exception.GetOriginalMessage()}");
					return false;
				}
			}
		}

		private void CollectDependencies(XElement root, PackageModel model, ILogWriter log = null)
		{
			foreach (var package in root.Descendants(XName.Get("PackageReference", root.Name.NamespaceName)))
			{
				var packageIdString = package.Attribute(XName.Get("Include", ""))?.Value.NormalizeNull();
				var versionString = package.Element(XName.Get("Version", root.Name.NamespaceName))?.Value.NormalizeNull();

				if (string.IsNullOrWhiteSpace(packageIdString))
				{
					continue;
				}

				StringKey packageId = packageIdString;
				SemanticVersion version;

				if (!string.IsNullOrWhiteSpace(versionString))
				{
					if (!SemanticVersion.TryParse(versionString, out version))
					{
						if (!Version.TryParse(versionString, out var systemVersion))
						{
							log?.WriteWarning($"Bad version: {versionString} - assuming <any>");
							version = SemanticVersion.Empty;
						}
						else
						{
							version = new SemanticVersion(systemVersion.Major, systemVersion.Minor, systemVersion.Build);
						}
					}
				}
				else
				{
					version = SemanticVersion.Empty;
				}

				var dependencyModel = new DependencyModel(packageId);

				if (!version.IsEmpty)
				{
					dependencyModel.Version = version.CompatibleRange();
				}

				model.Dependencies.Add(dependencyModel);
			}

			foreach (var project in root.Descendants(XName.Get("ProjectReference", root.Name.NamespaceName)))
			{
				var referencePath = project.Attribute(XName.Get("Include", ""))?.Value.NormalizeNull();
				var packageIdString = Path.GetFileNameWithoutExtension(referencePath);

				if (string.IsNullOrWhiteSpace(packageIdString))
				{
					continue;
				}

				var dependencyModel = new DependencyModel(new StringKey(packageIdString));

				if (!model.Version.IsEmpty)
				{
					dependencyModel.Version = model.Version.CompatibleRange();
				}

				model.Dependencies.Add(dependencyModel);
			}
		}
	}
}