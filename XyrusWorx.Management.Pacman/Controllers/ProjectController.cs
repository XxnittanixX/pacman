using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using JetBrains.Annotations;
using XyrusWorx.Collections;
using XyrusWorx.Diagnostics;
using XyrusWorx.IO;
using XyrusWorx.Runtime;

namespace XyrusWorx.Management.Pacman.Controllers
{
	class ProjectController
	{
		private readonly Application mApplication;
		private readonly List<PackagingStategy> mStrategies;

		public ProjectController([NotNull] Application application)
		{
			if (application == null)
			{
				throw new ArgumentNullException(nameof(application));
			}

			mStrategies = new List<PackagingStategy>();
			mApplication = application;
			mStrategies.Reset(
				from typeInfo in typeof(PackagingStategy).Assembly.GetLoadableTypeInfos()

				where !typeInfo.IsAbstract && !typeInfo.IsInterface
				where typeof(PackagingStategy).IsAssignableFrom(typeInfo.AsType())
				where typeInfo.DeclaredConstructors.Any(x => x.GetParameters().Length == 0)

				select (PackagingStategy) Activator.CreateInstance(typeInfo.AsType()));
		}

		public void Export([NotNull] BinaryContainer container, [NotNull] IBlobStore packageTarget)
		{
			if (packageTarget == null)
			{
				throw new ArgumentNullException(nameof(packageTarget));
			}

			if (container == null)
			{
				throw new ArgumentNullException(nameof(container));
			}

			foreach (var strategy in mStrategies)
			{
				var result = strategy.IsApplicable(container, mApplication.Log);
				if (result)
				{
					mApplication.Log.WriteInformation($"Strategy {strategy.GetType().Name} is applicable for input stream. Creating package model.");

					var packageModel = strategy.Process(container, mApplication.Log);
					var key = $"{Path.GetFileNameWithoutExtension(container.Identifier)}.nuspec";

					mApplication.Log.WriteInformation($"Exporting package to {key}");
					packageTarget.Erase(key);

					using (var stream = packageTarget.Open(key).AsText().Write())
					{
						packageModel.WriteDefinition(stream);
					}

					break;
				}
			}
		}
	}
}