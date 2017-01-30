using JetBrains.Annotations;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;
using XyrusWorx.Diagnostics;
using XyrusWorx.Management.ObjectModel;
using XmlNode = XyrusWorx.Management.IO.XmlNode;

namespace XyrusWorx.Management.Pacman.Strategies
{
	[UsedImplicitly(ImplicitUseKindFlags.InstantiatedWithFixedConstructorSignature)]
	public class MSBuildVersion15ProjectDefinition : XmlProjectDefinition
	{
		public MSBuildVersion15ProjectDefinition([NotNull] string projectFilePath) : base(projectFilePath) {}

		protected override IResult CreatePackageOverride(PackageModel package, ILogWriter log, string preRelease)
		{
			var title = GetProperties("AssemblyTitle").FirstOrDefault();
			var description = GetProperties("Description").FirstOrDefault();
			var copyright = GetProperties("Copyright").FirstOrDefault();

			var authorString = GetProperties("Authors").Take(1).FirstOrDefault(x => !string.IsNullOrWhiteSpace(x));
			var ownerString = GetProperties("Owners").Take(1).FirstOrDefault(x => !string.IsNullOrWhiteSpace(x));

			var projectUrlString = GetProperties("PackageProjectUrl").FirstOrDefault();
			var iconUrlString = GetProperties("PackageIconUrl").FirstOrDefault();
			var licenseUrlString = GetProperties("PackageLicenseUrl").FirstOrDefault();

			var versionString = GetProperties("VersionPrefix").FirstOrDefault();
			var languageString = GetProperties("NeutralLanguage").FirstOrDefault();

			package.Title = title.NormalizeNull() ?? package.Id.RawData;
			package.Description = description.NormalizeNull();
			package.Copyright = copyright.NormalizeNull();

			package.Authors.AddRange(authorString?.Split(',').Where(x => !string.IsNullOrWhiteSpace(x)) ?? new string[0]);
			package.Owners.AddRange(ownerString?.Split(',').Where(x => !string.IsNullOrWhiteSpace(x)) ?? new string[0]);

			TrySet(projectUrlString, s => new Uri(s), u => package.ProjectUrl = u, log);
			TrySet(iconUrlString, s => new Uri(s), u => package.IconUrl = u, log);
			TrySet(licenseUrlString, s => new Uri(s), u => package.LicenseUrl = u, log);
			TrySet(versionString, SemanticVersion.Parse, v => package.Version = v, log);
			TrySet(languageString, CultureInfo.GetCultureInfo, c => package.Culture = c, log);

			if (!package.Version.IsEmpty && !string.IsNullOrWhiteSpace(preRelease))
			{
				package.Version = package.Version.DeclarePreRelease(preRelease);
			}

			var frameworks = GetFrameworks().ToArray();
			if (frameworks.Length == 0)
			{
				frameworks = new[] { new StringKey() };
			}

			foreach (var framework in frameworks)
			{
				var packageReferences = GetItems("PackageReference", framework);
				var projectReferences = GetItems("ProjectReference", framework);

				foreach (var packageReference in packageReferences)
				{
					var referencePackageId = packageReference.Value("Include");
					var referenceVersionString = packageReference.Value("Version");

					if (string.IsNullOrWhiteSpace(referencePackageId))
					{
						continue;
					}

					if (!SemanticVersion.TryParse(referenceVersionString, out var version))
					{
						version = SemanticVersion.Empty;
					}

					package.Dependencies.Add(new DependencyModel(referencePackageId)
					{
						TargetFramework = framework.RawData.NormalizeNull(),
						Version = version.CompatibleRange()
					});
				}

				foreach (var projectReference in projectReferences)
				{
					var projectReferenceTarget = projectReference.Value("Include");

					if (string.IsNullOrWhiteSpace(projectReferenceTarget))
					{
						continue;
					}

					var version = package.Version;

					if (!version.IsEmpty && !string.IsNullOrWhiteSpace(preRelease))
					{
						version = version.DeclarePreRelease(preRelease);
					}

					package.Dependencies.Add(new DependencyModel(Path.GetFileNameWithoutExtension(projectReferenceTarget))
					{
						TargetFramework = framework.RawData.NormalizeNull(),
						Version = version.CompatibleRange()
					});
				}
			}

			return Result.Success;
		}
		protected override IResult TestOverride(XmlNode model, ILogWriter log)
		{
			if (model.Identifier != "Project")
			{
				return Result.CreateError($"Unexpected element: \"{model.Identifier}\"");
			}

			if (!SemanticVersion.TryParse(model.Value("ToolsVersion"), out var toolsVersion))
			{
				toolsVersion = SemanticVersion.Empty;
			}

			if (!toolsVersion.IsEmpty && toolsVersion < new SemanticVersion(15, 0))
			{
				return Result.CreateError($"Unsupported SDK tools version: {toolsVersion}");
			}

			return Result.Success;
		}

		protected override IEnumerable<StringKey> GetFrameworks()
		{
			var frameworkString = GetProperties("TargetFrameworks").FirstOrDefault() ?? string.Empty;
			var frameworks = frameworkString.Split(';');

			foreach (var framework in frameworks)
			{
				yield return framework;
			}
		}
		protected override IEnumerable<string> GetBinaryFiles(StringKey framework)
		{
			yield return $"{framework.RawData.NormalizeNull().TryTransform(x => $"{x}\\")}*.dll";
			yield return $"{framework.RawData.NormalizeNull().TryTransform(x => $"{x}\\")}*.pdb";
		}
		protected override IEnumerable<string> GetSourceFiles()
		{
			yield return "..\\..\\**\\*.cs";
		}

		private void TrySet<T>(string data, Func<string, T> getter, Action<T> setter, ILogWriter log)
		{
			try
			{
				if (!string.IsNullOrWhiteSpace(data))
				{
					setter(getter(data));
				}
			}
			catch (Exception exception)
			{
				log?.WriteError($"Invalid data: \"{data}\". {exception.GetOriginalMessage()}");
			}
		}

		private IEnumerable<string> GetProperties(StringKey key)
		{
			foreach (var propertyGroup in Model.Children("PropertyGroup"))
			{
				foreach (var value in propertyGroup.Values(key, new StringKey()))
				{
					yield return value;
				}
			}
		}
		private IEnumerable<XmlNode> GetItems(StringKey key, StringKey framework)
		{
			foreach (var propertyGroup in Model.Children("ItemGroup"))
			{
				var condition = propertyGroup.Value("Condition");

				if (!string.IsNullOrWhiteSpace(condition) && !framework.IsEmpty)
				{
					if (Regex.IsMatch(condition, @"\$\(\s*TargetFramework\s*\)"))
					{
						if (!Regex.IsMatch(condition, $@"'\$\(\s*TargetFramework\s*\)'\s*==\s*'{framework.RawData.ToRegexLiteral()}'"))
						{
							continue;
						}
					}
				}

				foreach (var element in propertyGroup.Children(key))
				{
					yield return element;
				}
			}
		}
	}
}