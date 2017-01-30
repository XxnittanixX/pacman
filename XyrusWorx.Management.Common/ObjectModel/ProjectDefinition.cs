using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using JetBrains.Annotations;
using XyrusWorx.Diagnostics;

namespace XyrusWorx.Management.ObjectModel
{
	[PublicAPI]
	public abstract class ProjectDefinition
	{
		[NotNull]
		public abstract IResult Load(ILogWriter log = null);

		[NotNull]
		public abstract IResult Test(ILogWriter log = null);

		[NotNull]
		public abstract Result<PackageModel> CreatePackage(ILogWriter log = null, string preRelease = null);
	}

	[PublicAPI]
	public abstract class ProjectDefinition<TSourceModel> : ProjectDefinition
	{
		private readonly FileInfo mProjectFile;
		private TSourceModel mModel;

		protected ProjectDefinition([NotNull] string projectFilePath)
		{
			if (projectFilePath == null)
			{
				throw new ArgumentNullException(nameof(projectFilePath));
			}

			mProjectFile = new FileInfo(projectFilePath);
		}

		public sealed override IResult Load(ILogWriter log = null)
		{
			log = log ?? new NullLogWriter();

			var modelReadResult = LoadSourceModel(log);
			if (modelReadResult.HasError)
			{
				return modelReadResult;
			}

			mModel = modelReadResult.Data;
			return Result.Success;
		}
		public sealed override IResult Test(ILogWriter log = null)
		{
			var loadResult = Load(log);
			if (loadResult.HasError)
			{
				return loadResult;
			}

			var testResult = TestOverride(mModel, log ?? new NullLogWriter());
			if (testResult.HasError)
			{
				return testResult;
			}

			return Result.Success;
		}
		public sealed override Result<PackageModel> CreatePackage(ILogWriter log = null, string preRelease = null)
		{
			var projectId = GetProjectId();
			var packageModel = new PackageModel(projectId);

			packageModel.Title = projectId.RawData;

			var frameworks = GetFrameworks().Where(x => !x.IsEmpty).ToArray();
			if (frameworks.Length == 0)
			{
				Include(packageModel, new PackageLibFolder(), GetBinaryFiles());
			}
			else
			{
				foreach (var framework in frameworks)
				{
					Include(packageModel, new PackageLibFolder{ChildFolder = new StringKeySequence(framework)}, GetBinaryFiles(framework));
				}
			}

			Include(packageModel, new PackageSourceFolder(), GetSourceFiles());
			Include(packageModel, new PackageContentFolder(), GetAssetFiles());

			var result = CreatePackageOverride(packageModel, log ?? new NullLogWriter(), preRelease);
			if (result.HasError)
			{
				return Result.CreateError<Result<PackageModel>>(result.ErrorDescription);
			}

			return new Result<PackageModel>(packageModel);
		}

		[NotNull]
		protected FileInfo ProjectFile => mProjectFile;

		[NotNull]
		protected TSourceModel Model
		{
			get
			{
				if (mModel == null)
				{
					throw new InvalidOperationException("The project was not loaded before being accessed.");
				}

				return mModel;
			}
		}

		[NotNull]
		protected abstract IEnumerable<StringKey> GetFrameworks();

		[NotNull]
		protected abstract Result<TSourceModel> LoadSourceModel([NotNull] ILogWriter log);

		[NotNull]
		protected virtual IResult TestOverride([NotNull] TSourceModel model, [NotNull] ILogWriter log) => Result.Success;

		[NotNull]
		protected virtual IResult CreatePackageOverride([NotNull] PackageModel package, [NotNull] ILogWriter log, [CanBeNull] string preRelease) => Result.Success;

		[NotNull]
		protected IEnumerable<string> GetBinaryFiles() => GetBinaryFiles(new StringKey());

		[NotNull]
		protected virtual IEnumerable<string> GetBinaryFiles(StringKey framework)
		{
			yield break;
		}

		[NotNull]
		protected virtual IEnumerable<string> GetSourceFiles()
		{
			yield break;
		}

		[NotNull]
		protected virtual IEnumerable<string> GetAssetFiles()
		{
			yield break;
		}

		protected virtual StringKey GetProjectId() => Path.GetFileNameWithoutExtension(ProjectFile.Name);

		private void Include(PackageModel package, PackageFolder folder, IEnumerable<string> items)
		{
			foreach (var item in items)
			{
				if (string.IsNullOrWhiteSpace(item))
				{
					continue;
				}

				var relativePath = GetRelativePath(ProjectFile.Directory, item);
				var definition = new PackageFileModel(relativePath, folder);

				package.Files.Add(definition);
			}
		}

		private string GetRelativePath(DirectoryInfo baseDirectory, [NotNull] string path, bool includeBaseDirectory = false)
		{
			if (path.NormalizeNull() == null)
			{
				throw new ArgumentNullException(nameof(path));
			}

			var baseDirectorySegments = baseDirectory.FullName.Split(Path.DirectorySeparatorChar);
			var fileSegments = path.Split(Path.DirectorySeparatorChar);

			var fileDirectoryPath = string.Join(Path.DirectorySeparatorChar.ToString(), fileSegments.Take(fileSegments.Length - 1));

			var commonAncestorSegments = new string[0];
			var commonAncestorLevel = -1;

			for (var i = 0; i < baseDirectorySegments.Length; i++)
			{
				var currentLevelSegments = baseDirectorySegments.Take(baseDirectorySegments.Length - i).ToArray();
				var currentLevelPath = string.Join(Path.DirectorySeparatorChar.ToString(), currentLevelSegments) + Path.DirectorySeparatorChar;

				if (fileDirectoryPath.StartsWith(currentLevelPath, StringComparison.OrdinalIgnoreCase))
				{
					commonAncestorSegments = currentLevelSegments;
					commonAncestorLevel = i;

					break;
				}
			}

			if (commonAncestorLevel < 0)
			{
				if (fileSegments[0].Contains(":"))
				{
					throw new ArgumentException($"The path \"{path}\" does not share a common ancestor with \"{baseDirectory.FullName}\".");
				}

				if (includeBaseDirectory)
				{
					return Path.Combine(baseDirectory.FullName, path);
				}

				return path;
			}

			var commonAncestorPath = string.Join(Path.DirectorySeparatorChar.ToString(), commonAncestorSegments);
			var baseToRootRelativePath = string.Join(Path.DirectorySeparatorChar.ToString(), Enumerable.Repeat("..", commonAncestorLevel - 1));

			if (includeBaseDirectory)
			{
				baseToRootRelativePath = Path.Combine(baseDirectory.FullName, baseToRootRelativePath);
			}

			return Path.Combine(baseToRootRelativePath, baseDirectory.FullName.Substring(commonAncestorPath.Length + 1));
		}
	}
}