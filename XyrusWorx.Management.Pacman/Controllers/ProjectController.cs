using JetBrains.Annotations;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using XyrusWorx.Collections;
using XyrusWorx.Diagnostics;
using XyrusWorx.IO;
using XyrusWorx.Management.ObjectModel;
using XyrusWorx.Runtime;

namespace XyrusWorx.Management.Pacman.Controllers
{
	class ProjectController
	{
		private readonly Application mApplication;
		private readonly List<Func<string, ProjectDefinition>> mDefinitionBuilders;

		public ProjectController([NotNull] Application application)
		{
			if (application == null)
			{
				throw new ArgumentNullException(nameof(application));
			}

			mDefinitionBuilders = new List<Func<string, ProjectDefinition>>();
			mApplication = application;

			mDefinitionBuilders.Reset(
				from typeInfo in typeof(ProjectDefinition).Assembly.GetLoadableTypeInfos()

				where !typeInfo.IsAbstract && !typeInfo.IsInterface
				where typeof(ProjectDefinition).IsAssignableFrom(typeInfo.AsType())
				where typeInfo.DeclaredConstructors.Any(x => x.IsPublic && x.GetParameters().Length == 1 && x.GetParameters()[0].ParameterType == typeof(string))

				select new Func<string, ProjectDefinition>(s => (ProjectDefinition)Activator.CreateInstance(typeInfo.AsType(), s)));
		}
		public void Export([NotNull] string filePath, IBlobStore packageTarget)
		{
			if (filePath.NormalizeNull() == null)
			{
				throw new ArgumentNullException(nameof(filePath));
			}

			var foundMatchingDefinition = false;
			var projectName = Path.GetFileNameWithoutExtension(filePath);
			var projectClass = Path.GetExtension(filePath).TrimStart('.');

			mApplication.Log.WriteVerbose($"Iterating project definition types to find best match for \"{projectClass}:{projectName}\"");

			foreach (var definitionBuilder in mDefinitionBuilders)
			{
				var definition = definitionBuilder(filePath);
				var definitionName = definition.GetType().Name;

				mApplication.Log.WriteVerbose($"Probing project definition type \"{definitionName}\" for \"{projectClass}:{projectName}\"");

				var definitionTestResult = definition.Test(mApplication.Log);
				if (definitionTestResult.HasError)
				{
					mApplication.Log.WriteVerbose($"Project definition type \"{definitionName}\" not applicable to \"{projectClass}:{projectName}\". Next...");
					continue;
				}

				foundMatchingDefinition = true;
				mApplication.Log.WriteInformation($"Packaging \"{projectClass}:{projectName}\" using \"{definitionName}\"");

				var createPackageResult = definition.CreatePackage(mApplication.Log);
				if (createPackageResult.HasError)
				{
					mApplication.Log.WriteError($"Failed to package \"{projectClass}:{projectName}\" using \"{definitionName}\"");
					continue;
				}

				var packageKey = createPackageResult.Data.Id + ".nuspec";
				var currentPackageTarget = packageTarget ?? new FileSystemStore(Path.GetDirectoryName(filePath));

				mApplication.Log.WriteInformation($"Successfully packaged \"{projectClass}:{projectName}\" using \"{definitionName}\"");
				mApplication.Log.WriteInformation($"Exporting \"{projectClass}:{projectName}\" to \"{Path.Combine(currentPackageTarget.Identifier.ToString(Path.DirectorySeparatorChar.ToString()), packageKey)}\"");

				currentPackageTarget.Erase(packageKey);

				using (var writer = currentPackageTarget.Open(packageKey).AsText().Write())
				{
					createPackageResult.Data.WriteDefinition(writer);
				}

				break;
			}

			if (!foundMatchingDefinition)
			{
				mApplication.Log.WriteWarning($"No known project definition type is applicable to \"{projectClass}:{projectName}\".");
			}
		}
	}
}