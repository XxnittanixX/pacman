using JetBrains.Annotations;

namespace XyrusWorx.Management.ObjectModel
{
	[PublicAPI]
	public class DependencyModel
	{
		private readonly StringKey mPackageId;

		public DependencyModel(StringKey dependencyPackageId)
		{
			mPackageId = dependencyPackageId;
		}

		public StringKey PackageId => mPackageId;
		public SemanticVersionRange Version { get; set; }

		[CanBeNull]
		public string TargetFramework { get; set; }
	}
}