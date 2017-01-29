using JetBrains.Annotations;

namespace XyrusWorx.Management.ObjectModel
{
	[PublicAPI]
	public class PackageContentFolder : PackageFolder
	{
		public sealed override StringKey Key => "content";
	}
}