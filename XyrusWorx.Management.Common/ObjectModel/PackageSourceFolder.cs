using JetBrains.Annotations;

namespace XyrusWorx.Management.ObjectModel
{
	[PublicAPI]
	public class PackageSourceFolder : PackageFolder
	{
		public sealed override StringKey Key => "src";
	}
}