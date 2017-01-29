using JetBrains.Annotations;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Xml.Linq;

namespace XyrusWorx.Management.ObjectModel
{
	[PublicAPI]
	public class PackageModel
	{
		private readonly StringKey mId;

		public PackageModel(StringKey packageId)
		{
			mId = packageId;
		}

		public StringKey Id => mId;
		public SemanticVersion Version { get; set; }

		[CanBeNull]
		public string Title { get; set; }

		[CanBeNull]
		public string Description { get; set; }

		[CanBeNull]
		public string Copyright { get; set; }

		[NotNull]
		public List<string> Authors { get; } = new List<string>();

		[NotNull]
		public List<string> Owners { get; } = new List<string>();

		[CanBeNull]
		public Uri ProjectUrl { get; set; }

		[CanBeNull]
		public Uri LicenseUrl { get; set; }

		[CanBeNull]
		public Uri IconUrl { get; set; }

		[CanBeNull]
		public CultureInfo Culture { get; set; }

		[NotNull]
		public List<DependencyModel> Dependencies { get; } = new List<DependencyModel>();

		[NotNull]
		public List<PackageFileModel> Files { get; } = new List<PackageFileModel>();

		[NotNull]
		public List<StringKey> Tags { get; } = new List<StringKey>();

		public void WriteDefinition([NotNull] TextWriter writer)
		{
			if (writer == null)
			{
				throw new ArgumentNullException(nameof(writer));
			}

			const string xmlns = "http://schemas.microsoft.com/packaging/2012/06/nuspec.xsd";

			var package = new XElement(XName.Get("package", xmlns));
			var metadata = new XElement(XName.Get("metadata", xmlns));
			var dependencies = new XElement(XName.Get("dependencies", xmlns));
			var files = new XElement(XName.Get("files", xmlns));

			package.Add(metadata);

			metadata.Add(new XElement(XName.Get("id", xmlns), Id.RawData ?? string.Empty));

			if (!string.IsNullOrWhiteSpace(Title))
			{
				metadata.Add(new XElement(XName.Get("title", xmlns), Title));
			}

			if (!string.IsNullOrWhiteSpace(Description))
			{
				metadata.Add(new XElement(XName.Get("description", xmlns), Description));
			}

			if (!string.IsNullOrWhiteSpace(Copyright))
			{
				metadata.Add(new XElement(XName.Get("copyright", xmlns), Copyright));
			}

			if (!Version.IsEmpty)
			{
				metadata.Add(new XElement(XName.Get("version", xmlns), Version.ToString(true)));
			}

			if (Authors.Any())
			{
				metadata.Add(new XElement(XName.Get("authors", xmlns), string.Join(",", Authors)));
			}

			if (Owners.Any())
			{
				metadata.Add(new XElement(XName.Get("owners", xmlns), string.Join(",", Owners)));
			}

			if (ProjectUrl != null)
			{
				metadata.Add(new XElement(XName.Get("projectUrl", xmlns), ProjectUrl.ToString()));
			}

			if (LicenseUrl != null)
			{
				metadata.Add(new XElement(XName.Get("licenseUrl", xmlns), LicenseUrl.ToString()));
				metadata.Add(new XElement(XName.Get("requireLicenseAcceptance", xmlns), "true"));
			}

			if (IconUrl != null)
			{
				metadata.Add(new XElement(XName.Get("iconUrl", xmlns), IconUrl.ToString()));
			}

			if (Culture != null)
			{
				metadata.Add(new XElement(XName.Get("language", xmlns), Culture.Name));
			}

			if (Tags.Any())
			{
				metadata.Add(new XElement(XName.Get("tags", xmlns), string.Join(",", Tags)));
			}

			if (Dependencies.Any())
			{
				var groups =
					from item in Dependencies
					where !string.IsNullOrWhiteSpace(item.TargetFramework)
					group item by item.TargetFramework into grouping
					select grouping;

				foreach (var group in groups)
				{
					var groupElement = new XElement(XName.Get("group", xmlns));
					groupElement.Add(new XAttribute(XName.Get("targetFramework", ""), group.Key));

					foreach (var dependency in group)
					{
						var dependencyElement = new XElement(XName.Get("dependency", xmlns));
						dependencyElement.Add(new XAttribute(XName.Get("id", ""), dependency.PackageId.RawData));

						if (!dependency.Version.IsEmpty)
						{
							dependencyElement.Add(new XAttribute(XName.Get("version", ""), dependency.Version.ToString()));
						}

						groupElement.Add(dependencyElement);
					}

					dependencies.Add(groupElement);
				}

				var common =
					from item in Dependencies
					where string.IsNullOrWhiteSpace(item.TargetFramework)
					select item;

				foreach (var dependency in common)
				{
					var dependencyElement = new XElement(XName.Get("dependency", xmlns));
					dependencyElement.Add(new XAttribute(XName.Get("id", ""), dependency.PackageId.RawData));

					if (!dependency.Version.IsEmpty)
					{
						dependencyElement.Add(new XAttribute(XName.Get("version", ""), dependency.Version.ToString()));
					}

					dependencies.Add(dependencyElement);
				}

				metadata.Add(dependencies);
			}

			if (Files.Any())
			{
				foreach (var file in Files)
				{
					var fileElement = new XElement(XName.Get("file", xmlns));

					fileElement.Add(new XAttribute(XName.Get("src", ""), file.Pattern));
					fileElement.Add(new XAttribute(XName.Get("target", ""), new StringKeySequence(file.TargetFolder.Key).Concat(file.TargetFolder.ChildFolder).ToString(Path.DirectorySeparatorChar.ToString())));

					files.Add(fileElement);
				}

				metadata.Add(files);
			}

			package.Save(writer, SaveOptions.None);
		}
	}
}